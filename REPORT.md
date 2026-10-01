# Fix 6223 — Tag is automatically removed when opening an email in a new window

Ticket: https://bugs.sogo.nu/view.php?id=6223 (minor, [SOGo] Web Mail)
Branch: `fix-6223-mantis` (commit `d984e4a4b`)
Verdict: **real bug, client-side (AngularJS)** — confirmed and fixed.

## Root cause

The bug is a one-line initialization-order defect in the `Message` service
constructor:

- `UI/WebServerResources/js/Mailer/Message.service.js:25-32` — the constructor
  calls `this.init(futureMessageData)` (which assigns `this.flags` from the
  provided data, e.g. `['_$label1']`) and **then** unconditionally executes
  `this.flags = []`, wiping the tags that `init()` just set.
- Same defect in the shipped bundle `UI/WebServerResources/js/Mailer.services.js`
  (Message constructor: `...this.init(s),...,this.flags=[]...`).

Full failure chain (matches the ticket's log exactly):

1. Main window: message is open (uid N) with tag `$label1`;
   `MessageController` (non-popup branch, `UI/WebServerResources/js/Mailer/MessageController.js:73-95`)
   watches `message.flags` and syncs additions/removals to the server via
   `addOrRemoveLabel`.
2. User clicks "open in a new window". The popup resolves its message from the
   opener: `UI/WebServerResources/js/Mailer/Mailer.popup.js:257-259`
   (`new Message(..., window.opener.$messageController.message.$omit({privateAttributes: true}))`).
3. The constructor's `this.flags = []` (line 32, **after** `init()`) erases the
   tags → the popup starts with `flags = []` (and the tag chips row is hidden).
4. The popup's `MessageController` detects it is a popup and one-way-syncs its
   flags back to the parent (`MessageController.js:47-58`):
   `ctrls.messageCtrl.message.flags = newTags` (the empty array).
5. The parent's watcher sees `newTags.length (0) < oldTags.length (1)` and calls
   `vm.message.removeTag(tag)` → **`POST .../addOrRemoveLabel`
   `{"operation":"remove",...}`** — the spurious request visible in the ticket's
   log, one second after `UIxMailPopupView` loads. The tag is removed
   server-side (IMAP keyword dropped).

Notes:
- Message-list items are unaffected (they are instantiated with `lazy=true`,
  `init()` runs later, so the `flags = []` default is legitimate there).
- `GET <msg>/view` returns no `flags` key at all (verified on the e2e stack),
  so the popup's initial tags can *only* come from the opener's message —
  wiping them in the constructor guarantees the bug.

## What changed (before/after)

`UI/WebServerResources/js/Mailer/Message.service.js` (constructor) — moved the
default initialization **before** `init()`:

Before:
```js
if (angular.isUndefined(lazy) || !lazy) {
  this.init(futureMessageData);
}
this.uid = parseInt(futureMessageData.uid);
this.selected = !!futureMessageData.selected;
this.level = parseInt(futureMessageData.level);
this.first = parseInt(futureMessageData.first) === 1;
this.flags = [];            // ← wiped the tags set by init() above
```

After:
```js
this.flags = [];            // default; overridden by init() when data has flags
if (angular.isUndefined(lazy) || !lazy) {
  this.init(futureMessageData);
}
this.uid = parseInt(futureMessageData.uid);
this.selected = !!futureMessageData.selected;
this.level = parseInt(futureMessageData.level);
this.first = parseInt(futureMessageData.first) === 1;
```

- `UI/WebServerResources/js/Mailer.services.js` — the identical token move
  applied surgically to the minified bundle (`this.flags=[]` moved before the
  `lazy || this.init(s)` expression), since that file ships to browsers
  (regenerating with the current terser would churn every bundle — repo
  convention is source-only fixes + periodic `chore(js/css)` regeneration).
- No Objective-C code touched.

Behavior impact:
- Popup now opens with the same tags as the parent window; the parent's watcher
  sees equal-length arrays → no `addOrRemoveLabel` POST → **tag preserved**.
- Lazy list items and tag-less instantiations still get `flags = []`.

## Tests

- New spec `Tests/spec/MailerMessageFlagsSpec.js` (jasmine, self-contained,
  no stack required; auto-discovered by `Tests/spec/support/jasmine.json`).
  It loads the real `Message.service.js` with angular/lodash stubs and locks:
  - bug 6223: `new Message(..., opener.$omit({privateAttributes:true}))`
    keeps `['_$label1']` (fails on the pre-fix code with `flags = []`,
    verified red/green);
  - `$omit({privateAttributes:true})` exposes `flags` (popup data path);
  - `flags` defaults to `[]` when data has none;
  - `flags` defaults to `[]` on lazy instantiation.
- No `Tests/Unit` (ObjC) test added: the fix is entirely client-side JS; the
  ObjC suite does not exercise AngularJS code (deviation from the default
  instruction, for this reason).
- Worktree unit suite
  (`local/run-worktree-tests.sh wt/c8-6223`): `Ran 61 tests` — the only
  failures are pre-existing on the pristine base commit (verified with
  `git stash`): `test_stringWithoutHTMLInjection` (documented host noise),
  `test_NGInternetSocketAddressFromString`-class dual-stack noise, and the 2
  `TestSOGoDraftObject` setUp errors ("Mailer.SOGo bundle missing") which come
  from the just-merged fix-6224 on this host, unrelated to this change.

## Verification steps for the orchestrator

JS unit spec (fast, no stack) — run from `Tests/` with the container's jasmine:
```sh
cd /workspace/Tests && npx jasmine --config=spec/support/jasmine.json \
  --filter="Mailer Message service"
# expect: 4 specs, 0 failures
```

Server-side round-trip sanity (stack at 127.0.0.1:50001, sogo-tests1/sogo) —
confirms the only client-visible mutation channel is `addOrRemoveLabel`, which
behaves correctly; the spurious 'remove' caller is now fixed client-side:
```sh
# login (cookie jar)
curl -s -c /tmp/cj -X POST http://127.0.0.1:50001/SOGo/connect \
  -H 'Content-Type: application/json' \
  -d '{"userName":"sogo-tests1","password":"sogo"}'
# create an isolated folder + message (via DAV PUT), then:
curl -s -b /tmp/cj -X POST \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/folderINBOX/foldertest-6223/addOrRemoveLabel \
  -H 'Content-Type: application/json' -H "X-XSRF-TOKEN: $(awk '$6=="XSRF-TOKEN"{print $7}' /tmp/cj)" \
  -d '{"operation":"add","msgUIDs":[1],"flags":"$LABEL1"}'   # → 204
# list: Flags shows ["$label1"]; GET .../1/view has no flags key (by design)
```
(All `test-6223-*` stack artifacts created during this investigation were
removed: INBOX copy batchDeleted, folder purged from Trash.)

In-browser repro check (manual, matches ticket steps): open a message → add a
tag → "open in a new window": before the fix the tag disappears (and one
`POST .../addOrRemoveLabel` 204 is logged); after the fix the tag stays on
both windows and no request is sent.

## PR body draft

When a message carrying a tag was opened in a new window, the tag was silently
removed: the mail popup resolves its message from the opener window via
`Message.$omit({privateAttributes: true})`, but the `Message` constructor
initialized `this.flags = []` **after** `init()` had already assigned the tags
from that data — so the popup always started with zero tags. The popup then
one-way-syncs its (now empty) flags array back to the parent window, whose
watcher interprets the shrink as a removal and fires a spurious
`addOrRemoveLabel` `operation=remove` request, dropping the IMAP keyword
server-side (bug 6223).

AVANT: open message → add tag "Important" → "open in a new window" → tag is
gone in both windows and `POST /SOGo/so/user/Mail/0/folderINBOX/addOrRemoveLabel`
(204) appears in the logs right after `UIxMailPopupView` loads.
APRÈS: the constructor initializes `flags` before `init()`, so tags provided in
the instantiation data are preserved; the popup opens showing the same tags as
the main window, the parent's watcher sees no change and no removal request is
sent. Lazy list instantiation and tag-less data still default to `flags = []`.
Covered by a new self-contained jasmine spec
(`Tests/spec/MailerMessageFlagsSpec.js`), verified red on the old code and
green with the fix.
