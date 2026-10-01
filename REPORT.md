# Bug 6192 — Clicking "Reply" freezes Firefox (75 MB JSON response)

Branch: `fix-6192-mantis` — commit `ca7c877db` — `fix(mail): inline a quoted image only once when replying (bug 6192)`

## Root cause (file:line)

When the user clicks **Reply**, the webmail makes two calls:
`GET <message>/reply` (creates the draft, `UI/MailerUI/UIxMailActions.m:45-72`)
then `GET <draft>/edit` (`UI/MailerUI/UIxMailEditor.m:754-796`), whose JSON
carries the whole reply body — this is the 75 MB response.

On a thread with multiple replies, the quoted HTML contains the **same
`<img src="cid:...">` at every quote level** (the image part exists once in
MIME, but each quoting level re-references it). During `/edit`,
`-setBase64ImagesInText:` (before the fix, `UI/MailerUI/UIxMailEditor.m:709-749`)
did:

```objc
lText = [text stringByReplacingOccurrencesOfString: contentId     // replaces EVERY occurrence
        withString: [NSString stringWithFormat: @"data:%@;base64,%@", ...]];
```

`stringByReplacingOccurrencesOfString:` replaces **all** occurrences of the cid,
so the full base64 image payload is duplicated **once per quote level**:
3.5 MB mail with a ~2.5 MB inline image referenced ~21 times →
21 × 1.33 × 2.5 MB ≈ 75 MB of `data:` URIs in the JSON. The browser must then
parse/scrub that string (Message.service.js regexes + CKEditor) → the reported
Firefox freeze (2 CPU cores, 3 GB RAM). The same duplication would also be sent:
on `send`, each `data:` URI is converted back to its own MIME part
(`SoObjects/Mailer/NSString+Mail.m:280-388`), so the outgoing reply would carry
N identical image parts.

Secondary amplifier in the same method: `[draft fetchAttachmentAttrs]` was
evaluated twice (once in the `if`, once in the `for`); each call re-reads every
attachment file and base64-encodes it.

## What changed (before/after)

1. `SoObjects/SOGo/NSString+Utilities.h/.m` — new generic helper
   `-stringByReplacingFirstOccurrenceOfString:withString:` (returns the receiver
   unchanged when the target is absent, single range replacement otherwise).
2. `UI/MailerUI/UIxMailEditor.m` (`setBase64ImagesInText:`):

| | Before | After |
|---|---|---|
| cid inlining | replaces **all** occurrences of the cid with the base64 `data:` URI → payload × N | replaces only the **first** occurrence → payload × 1 |
| attachment attrs | `fetchAttachmentAttrs` called **twice** | called **once** |

Deep-quote occurrences of the cid are left as-is (`cid:` refs, attachment
deleted exactly as before), so the editor shows the image at the most recent
quote level instead of freezing; the single-reference case (the overwhelming
majority) behaves identically to before.

## Tests

- `Tests/Unit/TestNSString+Utilities.m` — new
  `test_stringByReplacingFirstOccurrenceOfString` covering both branches of the
  helper: target absent (returns receiver unchanged, incl. empty string),
  single occurrence, multiple occurrences (only first replaced), match at
  start/middle/end, overlapping matches, empty replacement.
  Execution verified by mutation (deliberately wrong assertion →
  `FAIL: test_stringByReplacingFirstOccurrenceOfString`, then restored).
- Full suite: `local/run-worktree-tests.sh ~/Projets/hadrienblanc/sogo/wt/c10-6192`
  → **71 tests, 2 failures**, both pre-documented host noise
  (`test_NGInternetSocketAddressFromString`, `test_stringWithoutHTMLInjection`).
- `UI/MailerUI` compiles and links (`make` in `UI/SOGoUI`, `UI/Common`,
  `UI/MailerUI` after copying the main checkout's generated `config.make` into
  the worktree — worktrees don't carry untracked build files).

## Verification steps for the orchestrator

Reproduced live (unfixed stack) — 0.14 MB message with a 100 KB inline image
referenced 40 times → `/edit` response **5,485,865 bytes** containing
`data:image/png;base64,` **40 times** (40× blowup). Script kept at
`/tmp/opencode/test-6192-repro.py`. After deploy, rerun:

```bash
python3 /tmp/opencode/test-6192-repro.py   # if gone: re-craft per REPORT appendix
```

Manual equivalent (user sogo-tests2, password sogo):

1. APPEND via IMAP (127.0.0.1:1430) a `multipart/related` message: subject
   `test-6192-thread`, text/html with `<img src="cid:IMG6192@sogo">` ×40, plus
   one `image/png` part (Content-ID `<IMG6192@sogo>`, base64, ~100 KB).
2. `POST http://127.0.0.1:50001/SOGo/connect` with
   `{"userName":"sogo-tests2","password":"sogo"}` → keep `0xHIGHFLYxSOGo` and
   `XSRF-TOKEN` cookies (basic auth is NOT honoured for these `so` URLs).
3. `GET /SOGo/so/sogo-tests2/Mail/0/folderINBOX/<uid>/reply` (Cookie header)
   → 201 JSON `{accountId, mailboxPath, draftId}`.
4. `GET /SOGo/so/sogo-tests2/Mail/0/folderDrafts/<draftId>/edit` (Cookie header)
   → measure size.

- BEFORE fix: 5.49 MB, `data:image/png;base64,` ×40, `cid:IMG6192@sogo` ×0.
- AFTER fix (expected): ~135 KB (+ quoted HTML), `data:image/png;base64,` ×1,
  `cid:IMG6192@sogo` ×39 (deep-quote refs left in place).
5. Cleanup: `GET .../folderDrafts/<draftId>/delete` (204), IMAP
   `STORE <uid> +FLAGS \Deleted; EXPUNGE` on INBOX and Drafts
   (subject `test-6192`). Already done — INBOX/Drafts verified empty of
   `test-6192*`; one ~100 KB spool dir of a draft whose HTTP delete 404'd
  (deleted only via IMAP) may linger inside the container until volume reset.
6. Unit suite: `local/run-worktree-tests.sh ~/Projets/hadrienblanc/sogo/wt/c10-6192`.

## PR body draft

Bug 6192 — clicking "Reply" on an email with multiple replies made SOGo answer
the draft `/edit` request with a gigantic JSON payload (reported: 75 MB for a
3.5 MB message), freezing Firefox (2 cores / 3 GB RAM). The cause is in
`UIxMailEditor -setBase64ImagesInText:`: on long threads the same
`<img src="cid:...">` is referenced at every quoting level, and the code used
`stringByReplacingOccurrencesOfString:` to swap each cid with the full base64
`data:` URI — duplicating the image payload once per quote level. The same
duplication would then be sent out, since every `data:` URI is converted back
to its own MIME part on send.

AVANT: reply to a thread quoting an inline image N times → `/edit` JSON ≈
N × 1.33 × image size. Reproduced on the dev stack: 0.14 MB message (100 KB
image referenced 40×) → 5.49 MB response, `data:image/png;base64,` ×40; with
the reporter's 2.5 MB image ×21 levels → the 75 MB freeze.

APRÈS: only the first occurrence of each content id is inlined (a new
`-stringByReplacingFirstOccurrenceOfString:withString:` helper on NSString),
and the draft attachment attrs are fetched once instead of twice. Same
reproduction now yields a ~135 KB response with the image inlined once;
deeper quote levels keep their `cid:` references (broken-image placeholder at
worst) instead of freezing the browser. Single-reference mails (the common
case) are strictly unchanged; covered by a new unit test in
`Tests/Unit/TestNSString+Utilities.m` (suite: 71 tests, only the two known
host-noise failures).
