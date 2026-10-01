# Fix 6222 — Cyrillic tags cannot be added

Ticket: https://bugs.sogo.nu/view.php?id=6222 (minor, [SOGo] Web Mail)
Branch: `fix-6222-mantis`
Verdict: **real bug, server-side** — reproduced, fixed.

## Root cause

Two stacked defects, both triggered when a tag name contains non-ASCII
characters (Cyrillic, accents, CJK, emoji…):

1. **IMAP keywords are 7-bit atoms (RFC 3501)**. SOGo sent the label name
   verbatim in the STORE command: `UI/MailerUI/UIxMailFolderActions.m`
   `addOrRemoveLabelAction` unescaped the client flag with `fromCSSIdentifier`
   and passed it straight to `NGImap4Client storeFlags:forUIDs:addOrRemove:`,
   producing `UID STORE <uid> +FLAGS (тест)`. Verified against the e2e stack's
   Dovecot:

   ```
   a3 UID STORE 1 +FLAGS (тест)   →  a3 BAD Error in IMAP command UID STORE: 8bit data in atom
   ```

   The normalized result then carries `result = 0` and the action falls into
   its 500 error branch.

2. **The 500 branch crashed with the exception from the ticket log**:
   `NGImap4ResponseNormalizer.normalizeResponse:` stores the raw IMAP response
   under `RawResponse` (an `NGMutableHashMap`, SOPE's own map class), and
   `addOrRemoveLabelAction` serialized the whole dictionary with
   `responseWithStatus:500 andJSONRepresentation:`. `[NSDictionary jsonRepresentation]`
   recurses into values, hits `NSObject(SOGoObjectUtilities) jsonRepresentation`
   (SoObjects/SOGo/NSObject+Utilities.m:41) which calls `subclassResponsibility:`
   → `NSInvalidArgumentException: [NGMutableHashMap-jsonRepresentation] should be
   overridden by subclass` → the dispatcher converts the uncaught exception into
   **HTTP 501**, exactly as reported.

Reproduced live on the e2e stack (before the fix, code at `experimental`):

```sh
curl -s -c /tmp/cj -X POST http://127.0.0.1:50001/SOGo/connect \
  -H 'Content-Type: application/json' \
  -d '{"userName":"sogo-tests1","password":"sogo"}'
TOKEN=$(awk '$6=="XSRF-TOKEN"{print $7}' /tmp/cj)
curl -s -b /tmp/cj -o /dev/null -w "%{http_code}\n" -X POST \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/foldertest-6222/addOrRemoveLabel \
  -H 'Content-Type: application/json' -H "X-XSRF-TOKEN: $TOKEN" \
  --data-binary '{"operation":"add","msgUIDs":[1],"flags":"тест"}'
# → 501   (control: flags "testlabel" → 204, flags "café" → 501)
```

## What changed (before/after)

### 1. New label codec — `SoObjects/SOGo/NSString+Utilities.{h,m}`

`stringByEncodingImap4LabelName` / `stringByDecodingImap4LabelName`:
names that are already valid IMAP atoms (`[!-~]` minus `( ) { } % * " \ ]`)
pass through unchanged — **existing ASCII keywords are bit-identical, zero
migration**. Anything else (non-ASCII, or atom-specials such as spaces) is
encoded as `_u7_` + 4 hex digits per UTF-16 code unit, e.g.
`тест → _u7_0442043504410442`, `👍 → _u7_d83ddc4d` (surrogate pairs
supported). Decoding only fires on the `_u7_` marker followed by valid hex,
so legacy keywords (even ones containing `&` or `_`) are never touched.

Verified against Dovecot: `STORE +FLAGS (_u7_0442043504410442)` → OK,
`SEARCH KEYWORD _u7_0442043504410442` → hit, `-FLAGS` → OK.

### 2. `UI/MailerUI/UIxMailFolderActions.m`

- `addOrRemoveLabelAction`: flags are now
  `[[flag fromCSSIdentifier] stringByEncodingImap4LabelName]` before
  `storeFlags` — a Cyrillic tag now issues a valid `UID STORE` and returns
  **204**.
- `removeAllLabelsAction`: the user's `SOGoMailLabelsColors` keys (which the
  Preferences UI allows to be non-ASCII — `mailLabelKeyRE` only blocks atom
  specials) are encoded the same way before `storeFlags`.
- `getLabelsAction`: each folder keyword is decoded before the system-keyword
  check, the `SOGoMailLabelsColors` lookup (prefs keys hold decoded names) and
  the `imapName` reported to the UI — so the client round-trips decoded names.
- Both failure branches of `addOrRemoveLabel`/`removeAllLabels` now log the
  IMAP reason (`errorWithFormat`) and return a sanitized
  `{"reason": …}` 500 body — the `RawResponse`/`NGMutableHashMap` is never fed
  to `jsonRepresentation` anymore, killing the 501 crash for *any* future
  STORE failure.

### 3. `UI/MailerUI/UIxMailListActions.m`

- `getHeadersForUIDs:inFolder:` (used by the `headers` and `changes` actions):
  the per-message tags array is decoded, so the list/viewer chips show `тест`.
- `searchQualifier` (label filter + advanced-search `flags` filter): client
  label names are encoded before building the `(flags = …)` qualifier, so
  `SEARCH KEYWORD _u7_…` is issued instead of an invalid raw UTF-8 keyword.

Before → after (end to end):

```
AVANT  POST addOrRemoveLabel {"flags":"тест"}
       → UID STORE 1 +FLAGS (тест) → BAD
       → [NGMutableHashMap-jsonRepresentation] … → HTTP 501, no tag stored
APRÈS  POST addOrRemoveLabel {"flags":"тест"}
       → UID STORE 1 +FLAGS (_u7_0442043504410442) → OK → HTTP 204
       GET …/labels      → [{"imapName":"тест"}]
       POST …/headers    → tags: ["тест"]
       POST …/view {"labels":["тест"]} → the message is found
```

## Tests

- New unit suite `Tests/Unit/TestNSString+Imap4LabelName.m` (registered in
  `Tests/Unit/GNUmakefile`), 6 test methods covering every branch of the
  codec: atom-safe passthrough (`testlabel`, `$Label1`, `R&D`), encoding of
  Cyrillic/accents/space/`%`/parens/emoji, round-trips (incl. surrogate
  pairs), uppercase-hex decoding, and all decode guards (`_u7_`, non-hex,
  wrong length, legacy keywords with `&`), plus an atom-safety sweep of every
  produced keyword.
- New e2e spec `Tests/spec/MailerCyrillicLabelsSpec.js` (jasmine, needs the
  stack): creates folder `test-6222-labels` + one message, then locks the full
  flow — add Cyrillic tag → 204 (was 501), `labels` exposes the decoded name,
  message headers show the decoded tag, list filtering by the Cyrillic label
  finds the message, removal → 204. Cleanup in `afterAll`.
- Worktree unit suite (`local/run-worktree-tests.sh wt/c8-6222`):
  `Ran 67 tests` — only the 4 documented pre-existing failures remain
  (`test_NGInternetSocketAddressFromString`, `test_stringWithoutHTMLInjection`,
  2 × `TestSOGoDraftObject` setUp "Mailer.SOGo bundle missing"), identical to
  the pristine base tree. `UI/MailerUI` and `UI/SOGoUI` bundles compile and
  link with the change.

## Verification steps for the orchestrator

Unit (fast, on the merged tree):

```sh
local/run-worktree-tests.sh ~/Projets/hadrienblanc/sogo/sogo
# expect: Ran 67 tests, only the 4 known host-noise failures
```

E2e (inside the rebuilt `sogo_dev` container, per field notes):

```sh
cd /workspace/Tests && sed -i 's/port: "50001"/port: "50000"/' lib/config.js && \
npx jasmine --config=spec/support/jasmine.json --filter="Mailer cyrillic labels (bug 6222)"
# expect: 5 specs, 0 failures (restore lib/config.js afterwards)
```

Manual curl check against the rebuilt stack (same flow as the reproduction
above): the `addOrRemoveLabel` POST with `"flags":"тест"` must return **204**
(it returned 501 on `experimental`), and `GET …/labels` must list
`{"imapName":"тест"}`. All `test-6222*` stack artifacts used during
investigation were removed (folders `test-6222` and `foldertest-6222`
deleted).

## PR body draft

Adding a tag with non-ASCII characters (e.g. Cyrillic) from the webmail UI
failed with an HTTP 501 and an `NSInvalidArgumentException
[NGMutableHashMap-jsonRepresentation] should be overridden by subclass`.
Two problems stacked up: IMAP keywords are 7-bit atoms per RFC 3501, so the
raw UTF-8 name made the IMAP server reject the `UID STORE` command; and the
error branch of the action then tried to JSON-serialize the raw IMAP response
(an SOPE `NGMutableHashMap`) which no JSON serializer implements, turning a
clean 500 into an uncaught exception and a 501.

AVANT: open a message, type "тест" in the tag field, press Enter →
`POST …/addOrRemoveLabel` returns 501, the exception lands in sogod.log, no
tag is stored (same for any accented/CJK label, and for any label defined in
Preferences with a non-ASCII IMAP key).
APRÈS: label names that are not valid IMAP atoms are transparently encoded to
a `_u7_<hex>` ASCII keyword on write (`UID STORE … +FLAGS (_u7_0442…)`) and
decoded back everywhere they surface (folder labels list, per-message tags,
list filtering); existing pure-ASCII keywords are untouched, so nothing
changes for current users. IMAP failures on these actions now return a proper
500 JSON body with the server's reason instead of crashing. Covered by 6 new
unit tests on the codec and a new e2e spec locking the add → list → filter →
remove flow with a Cyrillic tag.
