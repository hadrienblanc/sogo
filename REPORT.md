# Ticket 6211 — HTML sanitization corrupts JSON in preferences

## Root cause

Two defects were reported:

1. **JSON corruption (fixed upstream before this branch).** Commit
   `67ce01ec2` ("fix(mail): sanitise mail with ics") replaced the per-handler
   regexes in `stringWithoutHTMLInjection`
   (SoObjects/SOGo/NSString+Utilities.m:1161) with
   `(on\w+)\s*=\s*(["'][^"']*["']|[^\s>]+)` → `on***=""`. Lacking a `\b`
   anchor, `(on\w+)` matched **inside** attribute names — in `content=`, the
   substring `ontent=` matched — and the template swallowed the attribute
   value *including its backslash-escaped quotes*. Applied to the raw JSON
   body in `saveAction` (UIxPreferences.m:1752-1754), this destroyed the JSON
   escaping (`\"content-type\"` → `con***="" charset`), so
   `objectFromJSONString` failed. This was fixed on `experimental` by
   `c45233c11` (the "next nightly" fix noted in the ticket) and refined by
   `10dc17334` (current `\bon(click|error|focus|load|mouseover|animationstart)[...]*=`
   → `data-blocked=`). I verified with a standalone probe against this
   worktree's framework that the ticket's exact payload now passes through the
   sanitizer **unchanged and still parses**: the regex regression is gone.

2. **Silent data loss on unparseable JSON (still live — fixed here).** When
   `objectFromJSONString` failed, `o` was `nil`, both `if ((v = [o objectForKey:...]))`
   blocks in `saveAction` (UIxPreferences.m:1757, 1997) were skipped, and the
   method fell through to `results = [self responseWithStatus: 200]`
   (UIxPreferences.m:2011): an empty **HTTP 200** with the user's changes
   silently discarded and no error surfaced — exactly what the ticket reports.

## What changed

`UI/PreferencesUI/UIxPreferences.m` — `saveAction`:

```objc
/* before */
o = [requestStr objectFromJSONString];
results = nil;
/* ...both branches silently skipped when o == nil... */
if (!results)
  results = (id <WOActionResults>) [self responseWithStatus: 200];

/* after */
o = [requestStr objectFromJSONString];
if (!o)
  return [self responseWithStatus: 400
           andJSONRepresentation: [NSDictionary dictionaryWithObjectsAndKeys: @"Invalid JSON payload", @"message", nil]];
```

- **AVANT**: `POST /SOGo/so/user/Preferences/save` with a body the sanitizer
  (or anything else) makes unparsable → `200` empty body, save silently
  dropped, UI shows "Preferences saved".
- **APRÈS**: same request → `400` + `{"message":"Invalid JSON payload"}`; the
  AngularJS client's `$save().catch()` suppresses the success toast, so the
  user is no longer told the save succeeded. (Verified in
  `PreferencesController.js:476-490`: non-2xx rejects the promise and skips
  the "Preferences saved" toast; 485 already handled the same way.)

The apidoc block of the endpoint gains the `@apiError (Error 400)` entry.

No change to `NSString+Utilities.m`: the regex regression was already fixed
upstream; this branch locks it with tests instead.

## Tests

- `Tests/Unit/TestNSString+Utilities.m` — new
  `test_stringWithoutHTMLInjectionOnJSONPayloads` (no GNUmakefile change
  needed, file already registered):
  - the ticket's exact payload (`meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\"`
    inside a JSON string) survives sanitization byte-identical **and** still
    parses via `objectFromJSONString`;
  - a real event handler inside a JSON string value is still neutralized
    (`onerror=` → `data-blocked=`) while the JSON stays parsable.
- `Tests/spec/HTTPPreferencesSpec.js` — two new e2e cases:
  - round-trip of a preference holding the ticket's escaped-quote HTML
    through `Preferences/save` + `jsonDefaults` (reuses the spec's
    `_setTextPref` helper — same raw-JSON escaping path as a signature,
    without polluting `SOGoMailIdentities` for other specs);
  - malformed JSON body → expects `400` (covers the new error branch; would
    fail with `200` before the fix).

## Verification steps for the orchestrator

Unit (host-noise: `test_NGInternetSocketAddressFromString`,
`test_stringWithoutHTMLInjection` are known failures on this machine; the
`sogo-tests` binary also segfaults at exit on this host — output is complete
before the crash, ignore the 139 exit code):

```
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
  /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c15-6211
# expected: "Ran 194 tests / FAILED (2 failures, 0 errors)" — only the 2 known ones
```

Manual build check of the touched UI bundle (needs `UI/SOGoUI` built once in
the worktree):

```
(cd UI/SOGoUI && make -s) && (cd UI/PreferencesUI && make -s)
```

e2e (stack must be up; jasmine filter matches full spec title):

```
# inside the sogo_dev container:
cd /workspace/Tests && sed -i 's/port: "50001"/port: "50000"/' lib/config.js
npx jasmine --config=spec/support/jasmine.json --filter="preferences"
# restore lib/config.js afterwards
```

Direct HTTP check of the new branch once the stack runs this build:

```
curl -s -c /tmp/cj -X POST http://127.0.0.1:50001/SOGo/connect \
     -H 'Content-Type: application/json' \
     -d '{"userName":"sogo-tests1","password":"sogo"}'
curl -s -b /tmp/cj -o /dev/null -w '%{http_code}\n' \
     -X POST http://127.0.0.1:50001/SOGo/so/sogo-tests1/Preferences/save \
     -H 'Content-Type: application/json' \
     -d '{ "defaults": { "signature": "con***='
# expected: 400   (was: 200)
```

## PR body draft

Since 5.12.8, saving preferences with an HTML signature containing attributes
such as `content` silently discarded the user's changes: the XSS-sanitizer
regex introduced by 67ce01ec (`(on\w+)\s*=...` → `on***=""`) matched *inside*
attribute names (`content=` → `ontent=`) and swallowed the attribute value
together with its escaped quotes, so the raw JSON body POSTed to
`Preferences/save` no longer parsed. `objectFromJSONString` then returned nil
and `saveAction` fell through to an empty HTTP 200 — no error, no save, while
the UI still displayed "Preferences saved". The regex itself was already
corrected on experimental (word-boundary anchored, explicit handler list,
value-preserving `data-blocked=` template); this PR locks that behavior with
unit tests and fixes the remaining error-handling gap.

`saveAction` now returns `400 {"message":"Invalid JSON payload"}` when the
request body cannot be parsed, instead of a silent 200. The web client
already treats non-2xx saves as failures (no success toast, promise
rejection — same path as the existing 485 TOTP error), so users get honest
feedback instead of silently losing their changes. New unit tests pin the
sanitizer↔JSON contract (ticket payload survives byte-identical and
parsable; real `on...=` handlers inside JSON values are still neutralized
without breaking the JSON), and two e2e cases cover the HTTP round-trip and
the new 400 branch.
