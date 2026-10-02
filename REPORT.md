# Ticket 6170 — Allow to display remote images from known senders

## Nature of the ticket

This is a **feature request** (status `acknowledged`, SOGo 6 backlog), not a bug
in existing behavior — nothing crashes and nothing is wrong today. The gap is in
the remote-inline-images policy of the web mail: the user preference
`SOGoMailDisplayRemoteInlineImages` only supports `never` / `always`
(UI/PreferencesUI/UIxPreferences.m:749-752), with no notion of "trusted sender"
and no exception for the Junk folder.

How the current machinery works (relevant for review):

- The HTML sanitizer renames every non-`cid:`, non-`data:` image source to
  `unsafe-src` (UI/MailPartViewers/UIxHTMLMailContentHandler.m:476-499), so
  remote images never load by themselves.
- The Angular client decides whether to rewrite `unsafe-*` back to real
  attributes: either the preference is `always`
  (UI/WebServerResources/js/Mailer/Message.service.js:69-71) or the user
  clicked "Load Images" ($loadUnsafeContent, Message.service.js:426).

## What changed

**1. New preference value `known` ("From known senders")**

- `UI/PreferencesUI/UIxPreferences.m:751` — the options list becomes
  `never, known, always`.
- `UI/PreferencesUI/English.lproj/Localizable.strings` — new label
  `displayremoteinlineimages_known` = "From known senders" (other languages
  fall back to English until translated).

**2. Server reports whether the sender is in the address book**

`UI/MailerUI/UIxMailView.m`:

- New private method `_senderIsInAddressBook` (UIxMailView.m:275): takes the
  envelope From, queries the user's contact folders with
  `allContactsFromFilter:` and requires an **exact, case-insensitive match** on
  `c_mail`. The exact check matters: `allContactsFromFilter:` is the
  autocomplete fuzzy search (`*filter*` on names and emails), so using it
  verbatim would let a sender like `<6170-known@sogo.local>` impersonate the
  card `test-6170-known@sogo.local` (substring match) and silently auto-load
  its tracking pixels. A missing From header yields `NO` (nil-guard on
  `[from length]`).
- In `-view:` (UIxMailView.m:411-413), when — and only when — the preference
  is `known`, the view JSON gains `senderInAddressBook: true|false`. The
  lookup is gated on the preference so `never`/`always` users pay no extra
  address-book query on message views.

**3. Client policy: junk exception + known senders**

`UI/WebServerResources/js/Mailer/Message.service.js` (+ regenerated bundle
`Mailer.services.js`, surgically edited like previous commits did — grunt is
not runnable here; the `.map` is left stale as in d984e4a4b):

- The factory now keeps the raw preference string instead of a boolean
  `always` flag (Message.service.js:69-70).
- `$content()` (Message.service.js:426-431) rewrites `unsafe-*` only when:

  ```
  $loadUnsafeContent                                    (explicit "Load Images" click)
  || (mailbox.type != 'junk'                            (Junk: automatic modes ignored)
      && (pref == 'always'
          || (pref == 'known' && senderInAddressBook)))
  ```

  This implements both requirements of the ticket: in the Junk folder the
  `always` and `known` settings are ignored (a message in Junk is untrusted,
  possibly spoofed), but the "This message contains external images" banner
  stays available (`$hasUnsafeContent` is untouched) so the user can still
  load images for a specific message — exactly the behavior the reporter
  clarified in note ~0018397.

**Before/after (AVANT/APRÈS)**

- AVANT — preference *Always display remote inline images*, message in Junk:
  tracking pixels load automatically when the message is opened.
- APRÈS — same situation: images stay blocked, banner + "Load Images" click
  still work for that message.
- AVANT — preference *Never*: images blocked for everyone, including senders
  already in your address book; per-message clicks needed.
- APRÈS — new option *From known senders*: images load automatically only for
  senders whose card exists (exact email match), still never in Junk.

**4. Out-of-scope fix required to build**

Commit 906d3030c `fix(mailer): restore MailerUI compilation broken by 48868446d`
adds the two missing semicolons after `ASSIGNCOPY` in
`UI/MailerUI/UIxMailEditor.m:556,560` — `experimental` currently fails to
compile the MailerUI bundle, which blocked verifying this change. Separate
commit, no behavior change.

## Tests

- `Tests/spec/MailerRemoteImagesPolicySpec.js` (new, pure JS, no stack): loads
  the real `Message.service.js` with stubbed angular/lodash/DOM (same pattern
  as SchedulerComponentControllerSpec.js / MailerIdentitySignatureSpec.js) and
  locks all 8 branches of the client policy: always+inbox, always+junk,
  known+known-sender, known+unknown-sender, known+junk, never, explicit click
  in junk, missing preference. Verified green locally:
  `node /tmp/opencode/t6170/harness.mjs` → ALL PASS.
- `Tests/spec/MailerRemoteImagesSpec.js` (new, e2e): covers **100% of the new
  server branches** — pref=known + exact card → `senderInAddressBook: true`
  (and body still sanitized to `unsafe-src`), substring spoofer → `false`,
  message without From → `false`, pref≠known → key absent. Cleans up its
  mailbox/card/preference (`test-6170-*`).
- No new `Tests/Unit` file: every line of new Objective-C code lives behind a
  live `WOContext` (active user, IMAP object, address books), which the unit
  harness cannot instantiate; per AGENTS.md the e2e spec is the right vehicle
  ("e2e spec in Tests/spec when a stack is needed").
- Worktree unit suite: `local/run-worktree-tests.sh wt/c15-6170` → 194 tests,
  only the two known host-noise failures (`test_NGInternetSocketAddressFromString`,
  `test_stringWithoutHTMLInjection`).
- Full `make` of the worktree passes (after the MailerUI compile fix).

## Verification steps for the orchestrator

The e2e stack was **down** while this agent ran (ports 1430/4191/2500 up, but
nothing listening on 50001; restarts are orchestrator-only), so the two specs
above must be run on the rebuilt stack:

```
cd /workspace/Tests && sed -i 's/port: "50001"/port: "50000"/' lib/config.js
npx jasmine --config=spec/support/jasmine.json --filter "remote inline images"
npx jasmine --config=spec/support/jasmine.json --filter "Message remote inline images policy"
sed -i 's/port: "50000"/port: "50001"/' lib/config.js
```

(`--filter` matches full spec titles: "Mail remote inline images from known
senders (bug 6170)" and "Message remote inline images policy (bug 6170)".)

Manual curl check once the stack runs this build, as sogo-tests1 (password
`sogo`):

```
# 1. create a card for the sender
curl -u sogo-tests1:sogo -X PUT -H 'Content-Type: text/vcard' \
  --data-binary $'BEGIN:VCARD\r\nVERSION:3.0\r\nUID:t6170\r\nFN:Known\r\nEMAIL:test-6170-known@sogo.local\r\nEND:VCARD\r\n' \
  http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Contacts/personal/test-6170-card.vcf
# 2. set the preference to "known" (via the web UI Preferences > Mail > General,
#    or POST /SOGo/so/sogo-tests1/Preferences/save with the defaults JSON)
# 3. send/put an HTML message with <img src="http://.../px.png"> from
#    test-6170-known@sogo.local, open it in the web mail: images load.
# 4. same message moved to Junk (mark as junk): images blocked, "Load Images"
#    banner present and functional.
# 5. raw view JSON: curl -b <cookie> \
#    http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/folderINBOX/<uid>/view \
#    → contains "senderInAddressBook":1 while the preference is "known".
```

## PR body draft

**feat(mail): display remote images from known senders, never automatically in
Junk (bug 6170)**

SOGo's remote-inline-images policy only knew two extremes: `never` (click
"Load Images" on every message) and `always` (every message, including Junk,
leaks your IP to any tracking pixel on open). This adds the middle ground
requested in bug 6170: a new preference **"From known senders"** that loads
remote images only when the envelope sender has a card in one of your address
books, and it makes the Junk folder exempt from the automatic modes — `always`
and `known` are ignored there because a message sitting in Junk is by
definition untrusted (possibly spoofed, per the reporter's clarification).
The "This message contains external images" banner and the per-message "Load
Images" click remain available everywhere, including Junk.

AVANT: with "Always", opening a spam message instantly fetched all its remote
images; with "Never", your own contacts' legitimate signatures and logos were
blocked until you clicked. APRÈS: with "From known senders", mail from senders
in your address book renders fully on open (exact, case-insensitive email
match — the autocomplete fuzzy search alone would let `<ple@sogo.local>`
impersonate `<example@sogo.local>`), unknown senders and everything in Junk
stay blocked, and one click still loads images for any given message.
Server-side the HTML sanitizer is unchanged (`unsafe-src` is still emitted);
only the message-view JSON gains a `senderInAddressBook` flag when the
preference is set to `known`, so other configurations pay no extra
address-book lookup. Covered by a pure-JS unit spec on the client policy and
an e2e spec on the server flag (exact match, substring spoof, missing From,
preference gating).
