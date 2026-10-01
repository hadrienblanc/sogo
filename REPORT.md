# Ticket 6183 — sending mail to all participants of an event misses organizer

**Branch:** `fix-6183-mantis`
**Mantis:** https://bugs.sogo.nu/view.php?id=6183 (Web Calendar, minor, 5.12.4)

## Root cause (file:line)

`UI/WebServerResources/js/Scheduler/ComponentController.js:42` — the toolbar
mail button of the event view (`UIxAppointmentViewTemplate.wox:78`,
"Email Attendees (internal users)") calls `newMessageWithAllRecipients`, which
built the recipient list from `component.attendees` only.

SOGo never adds the organizer to the ATTENDEE list (neither its own editor —
`UI/Scheduler/UIxComponentEditor.m:493` `_handleOrganizer` sets the ORGANIZER
property only — nor Outlook-style invites), and the backend serializes both
parties separately (`SoObjects/Appointments/iCalEntityObject+SOGo.m:119-175`
`attributesInContext:`). An attendee opening an invited event therefore held
`attendees = [themselves, ...]` with `organizer` in a distinct object, and the
composed message went to everyone except the organizer.

Verified read-only on the e2e stack: `GET
/SOGo/so/sogo-tests2/Calendar/personal/<uid>/view` (invitee copy of an event
organized by sogo-tests1) returns `organizer: {email: sogo-tests1...}` and
`attendees: [{email: sogo-tests2...}]` — the old code's recipients missed the
organizer entirely.

## What changed (before/after)

`ComponentController.js` (and the committed minified bundle
`UI/WebServerResources/js/Scheduler.services.js`, hand-patched the same way;
the stale `.map` is left as-is, matching the precedent of commit d984e4a4b):

AVANT — an invitee writes to "all participants" and the organizer is absent:

    recipients = ["Sogo Tests Two <sogo-tests2@sogo.local>"]

APRÈS — the organizer is prepended when not already among the attendees
(no duplicate when the organizer also chairs the event):

    recipients = ["Sogo Tests One <sogo-tests1@sogo.local>",
                  "Sogo Tests Two <sogo-tests2@sogo.local>"]

No backend/API change: the organizer/attendees JSON contract is unchanged; the
merge is purely client-side, guarded by `_.findIndex(...) < 0` (same pattern as
`Attendees.service.js:199`) and by `organizer && organizer.email` for events
without an organizer.

## Tests

- `Tests/Unit/TestiCalEntityObjectAttributes.m` (registered in
  `Tests/Unit/GNUmakefile`): locks the server-side JSON contract the fix
  consumes — organizer exposed separately with name falling back to the email,
  attendees never containing the organizer, no `organizer` key when absent.
  The `setUp` registers a dummy `SOGoMemcachedHost` so the user-manager cache
  path does not abort under libmemcached with a NULL host (host landmine,
  unrelated to the fix).
- `Tests/spec/SchedulerComponentControllerSpec.js`: stack-independent jasmine
  spec that loads `ComponentController.js` with stubbed angular/lodash
  dependencies and asserts the recipients of `newMessageWithAllRecipients`:
  organizer included for an invited event, no duplicate when the organizer is
  also a (CHAIR) attendee, attendees-only fallback without organizer. Verified
  red on `experimental` sources and green on the fixed ones.
- Unit suite: `local/run-worktree-tests.sh` → `Ran 99 tests, FAILED (2
  failures, 0 errors)` — the 2 failures are the known host-noise
  (`test_NGInternetSocketAddressFromString`,
  `test_stringWithoutHTMLInjection`). The process exit code 139 after the
  report reproduces identically on the untouched main checkout
  (GNUstep autorelease-pool teardown quirk of this host) and is not caused by
  this change.

## Verification steps for the orchestrator

1. Unit suite:
   `local/run-worktree-tests.sh ~/Projets/hadrienblanc/sogo/wt/c11-6183`
   → expect `Ran 99 tests` with only the two known failures.
2. JS spec (after merge, inside `sogo_dev`):
   `cd /workspace/Tests && npx jasmine --config=spec/support/jasmine.json --filter="ComponentController mail recipients"`
3. e2e data contract (stack, any user pair) — reproduce then clean up:
   ```
   curl -u sogo-tests1:sogo -X PUT -H 'Content-Type: text/calendar' \
     --data-binary @event.ics \
     http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/personal/test-6183-x.ics
   # invitee-shaped copy (ORGANIZER=sogo-tests1, ATTENDEE=sogo-tests2) into sogo-tests2
   curl -c /tmp/c -X POST -H 'Content-Type: application/json' \
     -d '{"userName":"sogo-tests2","password":"sogo"}' http://127.0.0.1:50001/SOGo/connect
   curl -s -b /tmp/c http://127.0.0.1:50001/SOGo/so/sogo-tests2/Calendar/personal/test-6183-x.ics/view
   # → JSON with "organizer" (sogo-tests1) distinct from "attendees" (sogo-tests2)
   curl -u sogo-tests1:sogo -X DELETE .../test-6183-x.ics  (both users)
   ```
4. UI smoke (after image rebuild): open an invited event in the web calendar,
   click the mail icon next to Close → compose window "To" must list the
   organizer first, then the other attendees.

## PR body draft

L'icône courriel de la fiche événement (« Envoyer un courriel à tous les
participants ») construisait la liste des destinataires à partir des seuls
`attendees`. Or SOGo (comme Outlook) n'inscrit jamais l'organisateur parmi les
participants : l'`ORGANIZER` est sérialisé à part dans le JSON `/view`
(`iCalEntityObject+SOGo.m attributesInContext:`), et `_handleOrganizer` ne
génère pas d'`ATTENDEE` correspondant. Résultat : un invité qui écrit à « tous
les participants » excluait précisément l'organisateur de la réunion
(bug 6183) — sur la démo SOGo comme en production.

AVANT : destinataires = participants uniquement →
`["Sogo Tests Two <sogo-tests2@sogo.local>"]`.

APRÈS : `newMessageWithAllRecipients` préfixe l'organisateur lorsqu'il n'est
pas déjà listé comme participant (pas de doublon quand il préside aussi
l'événement via un `ATTENDEE;ROLE=CHAIR`) →
`["Sogo Tests One <sogo-tests1@sogo.local>",
  "Sogo Tests Two <sogo-tests2@sogo.local>"]`.

Le correctif est purement côté client (`ComponentController.js` + bundle
minifié régénéré à la main, précédent d984e4a4b) ; aucun changement d'API. Le
contrat JSON serveur (organizer/attendees distincts, repli du nom sur
l'adresse) est verrouillé par `Tests/Unit/TestiCalEntityObjectAttributes.m`,
et la logique de fusion par `Tests/spec/SchedulerComponentControllerSpec.js`
(verte sur le correctif, rouge sur `experimental`).
