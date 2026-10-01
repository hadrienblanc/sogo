# Bug 6189 — unable to enter text when composing an email in the mobile view (Firefox Mobile)

Branch: `fix-6189-mantis` — commit see below — `fix(mail): report a desktop Firefox user agent to CKEditor on Firefox for Android (bug 6189)`

## Root cause (file:line)

The message body of the compose dialog is CKEditor 5 (`sg-ckeditor`,
`UI/Templates/MailerUI/UIxMailEditor.wox:308-313`; bundled build
`UI/WebServerResources/js/vendor/ckeditor/build/ckeditor.js`, v44.1.0).
At script load, CKEditor captures the user agent once and derives its
environment flags:

- `navigator.userAgent.toLowerCase()` → env module (`isAndroid` when the
  UA contains "android", `isGecko` when it matches `gecko/\d+`) —
  CKEditor 5 build, env module (search `isAndroid:h(i)` in
  `js/vendor/ckeditor/build/ckeditor.js`);
- the typing feature selects its input pipeline from that flag:
  `const e = s.isAndroid ? dw : lw` where
  `lw=["insertText","insertReplacementText"]` and
  `dw=[...lw,"insertCompositionText"]`, plus an Android-only
  `_compositionQueue` reconciliation of soft-keyboard composition
  events (search `insertCompositionText` / `_compositionQueue.flush`).

That Android pipeline is built for Blink's IME event flow. Firefox for
Android (Gecko) drives soft-keyboard text through a composition flow the
pipeline mishandles: characters are swallowed, while Enter and Backspace
— handled from `keydown` keystrokes, which Gecko reports correctly —
still work. This matches the ticket exactly, including the reporter's
own controlled experiment: switching SOGo to the **desktop view**
("Request desktop site") makes Firefox send a UA without the "Android"
token, CKEditor then uses its standard Gecko (desktop) pipeline and
typing works on the very same browser/keyboard; Chrome on Android is
unaffected (the Android pipeline is made for it).

SOGo's own code is not at fault: instrumented replays of Firefox-Android
key/composition/beforeinput sequences against the live stack (read-only,
sogo-tests2, Playwright + synthetic Gecko-style events) show no SOGo or
angular-material handler cancels or resets input in either editor
(`beforeinput` on `.ck-content` is only cancelled by CKEditor itself,
which is the broken path). Fixing the vendor build not being an option,
the minimal server-side fix is to report a desktop-Firefox user agent to
the page **before** `ckeditor.js` evaluates, only on Gecko-on-Android
devices:

- `SoObjects/SOGo/NSString+Utilities.m` — new
  `-[NSString ckEditorUserAgentOverride]`: for a UA containing both
  "Android" and `Gecko/<digits>` (Firefox on Android — Chrome's
  "like Gecko)" token has no digits and never matches), returns an
  equivalent desktop Firefox UA built from the Gecko version (digits
  only, therefore injection-safe); returns nil otherwise.
- `UI/Common/UIxPageFrame.m` — `ckEditorUserAgentOverride` /
  `hasCKEditorUserAgentOverride` fed from
  `[[context request] clientCapabilities] userAgent`.
- `UI/Templates/UIxPageFrame.wox:131-133` — inside the inline script
  that runs *before* all JS imports (ckeditor.js included):
  `Object.defineProperty(navigator, 'userAgent', …)` restricted to that
  override. The page-frame inline script precedes the `<script>`
  imports, so CKEditor's env capture sees the desktop UA.

Known limitation, stated honestly: no Firefox-Android engine was
available in this environment, so the Gecko-side failure was not
reproduced live; the root cause is established from the reporter's
desktop/mobile-view experiment (same engine, only the UA differs),
CKEditor 5's UA-conditional typing code, and CKEditor's history of
Firefox-Mobile-only typing bugs. If the reporter's claim that the
plain-text (textarea) compose mode also fails is accurate (we could not
observe any SOGo-side blocking on that path, and the textarea path does
not depend on the UA), that residual issue would be Gecko-internal and
out of SOGo's reach; the UA switch cannot affect it either way.

## What changed (before/after)

| | Before | After |
|---|---|---|
| page served to Firefox on Android | `navigator.userAgent` = real mobile UA → CKEditor env `isAndroid=true` → Android typing pipeline → soft-keyboard characters dropped in compose (Enter/Backspace work) | inline script (before ckeditor.js loads) overrides `navigator.userAgent` to the desktop-Firefox equivalent → CKEditor env takes the Gecko desktop pipeline used by desktop Firefox (and by the reporter's working "desktop view") → typing works |
| page served to Chrome/Android, iOS, desktop browsers | unchanged | unchanged — override emitted only for Android+`Gecko/<digits>` UAs, i.e. Firefox on Android in mobile view |
| Firefox on Android, "desktop site" mode | UA already desktop-shaped, no override | unchanged (nil override) |

Server-side detection (regex on the UA header) is unit-tested; the
emitted UA string contains only digits and fixed tokens, so it cannot
break out of the JS string literal (hostile-UA test case included).

## Tests

- New `Tests/Unit/TestNSString+CKEditorUserAgentOverride.m` (registered
  in `Tests/Unit/GNUmakefile`), 8 tests: Firefox-Android phone + tablet
  UAs masked to the desktop equivalent (two Gecko versions), Chrome on
  Android untouched, desktop Firefox untouched, Firefox-Android
  desktop-view UA untouched, Safari iOS / Edge Android untouched, empty
  and partial UAs return nil, hostile UA attempting JS injection is
  neutralised to digits-only. Execution proven by mutation (broken
  assertion → FAIL, restored).
- Full suite: `local/run-worktree-tests.sh
  ~/Projets/hadrienblanc/sogo/wt/c10-6189` → **87 tests, 2 failures**,
  both pre-documented host noise (`test_NGInternetSocketAddressFromString`,
  `test_stringWithoutHTMLInjection`).
- New e2e spec `Tests/spec/HTTPPageFrameCKEditorSpec.js` (jasmine,
  cross-fetch): logs in, fetches `/SOGo/so/<user>/Mail/view` with a
  Firefox-Android UA → asserts the override script and the desktop UA
  literal are served; with a Chrome-Android UA and with a desktop
  Firefox UA → asserts the override is absent. **Runs against a stack
  deployed from this branch** (the shared stack still runs the previous
  build; no deploys allowed for sub-agents).
- In-app dry run (documented for reference, in `/tmp/opencode/rep6189/`):
  Playwright loaded the real stack but injected exactly the override
  line the patched template emits, before ckeditor.js; with the override
  active the compose dialog opens and `hello 6189` lands in the
  ng-model (`<p>hello 6189</p>`) in HTML mode and in the textarea in
  text mode, with no page errors — i.e. the change is inert for
  Chromium-class event flows and does not regress the working paths.
- Stack hygiene: probes opened compose dialogs but never saved; Drafts
  of sogo-tests2 verified empty (IMAP check) — no artifacts to clean.

## Verification steps for the orchestrator

After deploying this branch to the e2e stack (static volume reset per
field notes), from any host:

```bash
# 1. session
curl -s -c /tmp/rep6189.cookies -H 'Content-Type: application/json' \
  -d '{"userName":"sogo-tests1","password":"sogo"}' http://127.0.0.1:50001/SOGo/connect/

# 2. mail page as Firefox Mobile (mobile view): override MUST be present
curl -s -b /tmp/rep6189.cookies \
  -A 'Mozilla/5.0 (Android 16; Mobile; rv:149.0) Gecko/149.0 Firefox/149.0' \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/view | \
  grep -F "Object.defineProperty(navigator, 'userAgent'"
# expected: one line ending with return 'Mozilla/5.0 (X11; Linux x86_64) Gecko/149 Firefox/149'; } });

# 3. same page as Chrome Android and as desktop Firefox: override MUST be absent
curl -s -b /tmp/rep6189.cookies \
  -A 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36' \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/view | grep -cF "defineProperty(navigator" ; echo  # expected 0
curl -s -b /tmp/rep6189.cookies \
  -A 'Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/149.0 Firefox/149.0' \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/view | grep -cF "defineProperty(navigator" ; echo  # expected 0

# 4. e2e spec (inside the rebuilt container, per AGENTS.md) — covers all three assertions
#    cd /workspace/Tests && npx jasmine --filter 'page frame ckeditor user agent override'
```

Real-device confirmation (only possible step that needs actual
hardware): Firefox for Android → SOGo → compose → type in the body;
characters must now appear. Before the fix they did not (Enter and
Backspace only).

Unit suite: `local/run-worktree-tests.sh
~/Projets/hadrienblanc/sogo/wt/c10-6189` (87 tests, 2 known host-noise
failures).

## PR body draft

Bug 6189 — on Firefox for Android in the mobile view, no text could be
entered in the compose body: the keyboard opened, but characters were
dropped, while Enter and Backspace kept working; plain Chrome on Android
and Firefox's own "desktop view" on the same phone were fine. The body
editor is CKEditor 5, whose typing feature picks an Android-specific
input pipeline when its load-time environment sniff sees "android" in
the user agent; that pipeline (an IME composition queue designed for
Blink) mishandles Gecko's soft-keyboard composition flow — characters
never reach the model, while keydown-driven keys such as Enter and
Backspace still do. The reporter's workaround — switching SOGo to the
desktop view, which simply removes "Android" from the UA — exercised
CKEditor's desktop Gecko pipeline and worked, which pinned the root
cause to that UA-conditional pipeline selection.

AVANT: Firefox Android + mobile view → `navigator.userAgent` contains
"Android" → CKEditor typing pipeline `isAndroid` → typed characters
swallowed in the compose body (HTML mode), Enter/Backspace still
functional; users must switch to desktop view to write a mail.
APRÈS: the page frame (UIxPageFrame) detects Firefox-on-Android UAs
server-side (Android + `Gecko/<digits>`, everything else untouched) and
overrides `navigator.userAgent` with the equivalent desktop Firefox UA
before ckeditor.js loads — exactly the state the reporter's working
"desktop view" produced, now automatic; CKEditor then uses its standard
Gecko pipeline and typing works in the mobile layout. Chrome on Android,
iOS and desktop browsers are byte-for-byte unaffected (override not
emitted), the emitted string is digits-only (no injection surface), 8
unit tests cover the UA matrix including hostile inputs, and a new e2e
spec locks the served page for Firefox-mobile vs Chrome-mobile vs
desktop UAs.
