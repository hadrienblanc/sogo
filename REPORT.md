# Bug 6132 — Invitations cannot be added to calendar when Participation Role is missing

Branch: `fix-6132-mantis` (worktree `wt/c14-6132`), commit `17a9989b4`.

## Verdict on the reported symptom

**The reported failure does NOT reproduce on current code** — the exact repro
from the ticket (embedded `METHOD:REQUEST` with
`ATTENDEE;CN=Jean Dupont;RSVP=TRUE:mailto:...`, i.e. ROLE and PARTSTAT
stripped as iCalcreator does) was driven live on the shared e2e stack
(http://127.0.0.1:50001, sogo-tests1):

- invitation viewer renders Accept / Decline / Tentative / Delegate /
  Add-to-calendar buttons (attendee recognised via email only),
- `accept` → HTTP 204, event stored in `Calendar/personal/` with
  `PARTSTAT=ACCEPTED` set,
- `addToCalendar` → HTTP 204, event stored,
- CalDAV `PUT` of the same payload → HTTP 201 (Outlook+CalDAV-synchronizer flow).

The relevant sources are byte-identical to upstream SOGo 5.12.1 (verified by
diff against `Alinto/sogo@SOGo-5.12.1` for `UIxMailPartICalActions.m`,
`UIxMailPartICalViewer.m`, `SOGoAppointmentObject.m` core and the ActiveSync
files), so the ticket's storage-side symptom must come from the reporter's
specific client/version, not from a ROLE gate in these paths.

Why it works: `-[CardElement value:ofAttribute:]` (SOPE/NGCards/CardElement.m:391)
returns `@""` for absent parameters, and every consumer on the add-to-calendar
paths only special-cases *non-default* values:

- `userIsAttendee:` / `userAsAttendee:` match by email (iCalEntityObject+SOGo.m:433/453),
- `_addOrUpdateEvent:` only skips NON-PARTICIPANT attendees (SOGoAppointmentObject.m:203),
- `_handleAttendee:` sets the new PARTSTAT because `@"" != "ACCEPTED"`
  (SOGoAppointmentObject.m:1486),
- the viewer uses `partStatWithDefault` (NEEDS-ACTION default, iCalPerson.m:162),
  already RFC-compliant.

## Root cause of what *was* wrong (file:line)

`ActiveSync/iCalEvent+ActiveSync.m:245` — the EAS `Attendee_Type` mapping
compared the **raw** ROLE:

```objc
if ([[attendee role] caseInsensitiveCompare: @"REQ-PARTICIPANT"] == NSOrderedSame)
  attendee_type = 1;   // required
else
  attendee_type = 2;   // optional
```

With ROLE absent (the RFC 5545 §3.2.16 default being REQ-PARTICIPANT — exactly
what iCalcreator strips, see
`CalAddressFactory::inputPrepAttendeeParams` `$DEFAULTSTOREMOVE`), the mapping
fell through to `attendee_type = 2` ("optional"), so Microsoft clients
(reporter platform: Windows 11) render the invited user as an *optional*
attendee of the synced meeting — the one place SOGo genuinely mishandled the
missing-ROLE default. `partStatWithDefault` existed but no ROLE counterpart.

## What changed

Before: missing ROLE → ActiveSync `Attendee_Type=2` (optional), no
RFC-default accessor for ROLE.

After:

- `SOPE/NGCards/iCalPerson.h/.m` — new `-[iCalPerson roleWithDefault]`
  mirroring the existing `partStatWithDefault` (returns `REQ-PARTICIPANT`
  when the parameter is absent or empty, verbatim value otherwise).
- `ActiveSync/iCalEvent+ActiveSync.m` — the `Attendee_Type` mapping now uses
  `[attendee roleWithDefault]`, so a stripped ROLE maps to type 1 (required)
  per RFC 5545, while explicit `OPT-PARTICIPANT`/`NON-PARTICIPANT` still map
  to type 2.

AVANT (ICS, iCalcreator-style):

```
ATTENDEE;CN=Jean Dupont;RSVP=TRUE:mailto:tout-le-monde@sogo.nu
```

→ EAS: `<Attendee_Type>2</Attendee_Type>` (optional, wrong — ROLE absent
means REQ-PARTICIPANT per RFC 5545 §3.2.16)

APRÈS: same ICS → `<Attendee_Type>1</Attendee_Type>` (required), matching the
behaviour of an explicit `ROLE=REQ-PARTICIPANT`.

## Tests

`Tests/Unit/TestiCalEvent+ActiveSync.m` (existing file, no GNUmakefile change):

- `test_missingAttendeeRoleDefaultsToRequiredOnTheWire` — bare ATTENDEE →
  `Attendee_Type=1` and `Attendee_Status=5` (NEEDS-ACTION default) in
  `activeSyncRepresentationInContext:`;
- `test_explicitOptionalAttendeeRoleStaysOptionalOnTheWire` — explicit
  `ROLE=OPT-PARTICIPANT` still → `Attendee_Type=2` (locks the other branch).

`Tests/Unit/TestiCalPerson+SOGo.m` (existing file, reuses the SOGoUser stub):

- `test_attendeeWithoutRoleAndPartStatStaysInvitable` — locks the
  non-reproducibility: `userIsAttendee:` YES, `userAsAttendee:` found,
  `roleWithDefault` = REQ-PARTICIPANT, `partStatWithDefault` = NEEDS-ACTION,
  attendee kept in `participants` (not filtered as NON-PARTICIPANT);
- `test_explicitRoleAndPartStatAreKeptVerbatim` — explicit
  `ROLE=OPT-PARTICIPANT;PARTSTAT=TENTATIVE` passed through unchanged.

Run:

```
local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c14-6132
# Ran 184 tests — FAILED (2 failures, 0 errors)
# -> test_NGInternetSocketAddressFromString   (known host noise)
# -> test_stringWithoutHTMLInjection          (known host noise)
```

Same 2 known host-noise failures as a clean tree; the 4 new tests pass
(180 → 184).

## Verification steps for the orchestrator

Live reproduction of the ticket scenario on the shared stack (artifacts
prefixed `test-6132-`, all cleaned up afterwards — verified 0 remaining
events/mails):

```bash
# 1. deliver an invitation whose ATTENDEE lacks ROLE/PARTSTAT (RFC defaults)
#    (mail delivered via SMTP 127.0.0.1:2500, From jean@external.example,
#     text/calendar; method=REQUEST part with
#     ATTENDEE;CN=Jean Dupont;RSVP=TRUE:mailto:sogo-tests1@example.org)

# 2. session cookie
curl -s -c /tmp/c.txt -X POST -H 'Content-Type: application/json' \
  -d '{"userName":"sogo-tests1","password":"sogo"}' http://127.0.0.1:50001/SOGo/connect

# 3. accept the invitation from the mail viewer (part "2")
T=$(grep XSRF /tmp/c.txt | awk '{print $NF}')
curl -s -b /tmp/c.txt -X POST -H "X-XSRF-TOKEN: $T" \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/folderINBOX/<MSGUID>/2/accept \
  -w '%{http_code}\n'   # -> 204

# 4. event stored with the applied status (repeat with addToCalendar / a
#    CalDAV PUT of the same payload -> 201)
curl -s -u sogo-tests1:sogo \
  http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/personal/test-6132-norole@example.org
# -> ATTENDEE;PARTSTAT=ACCEPTED;CN=Jean Dupont:mailto:sogo-tests1@example.org

# 5. unit suite
local/run-worktree-tests.sh ~/Projets/hadrienblanc/sogo/wt/c14-6132
```

## PR body draft

Invitations emitted by iCalcreator-based systems strip the ATTENDEE
parameters that equal their RFC 5545 defaults (`ROLE=REQ-PARTICIPANT`,
`PARTSTAT=NEEDS-ACTION`, see iCalcreator's `CalAddressFactory::$DEFAULTSTOREMOVE`),
producing lines such as `ATTENDEE;CN=Jean Dupont;RSVP=TRUE:mailto:…`. Bug 6132
reported that such invitations could not be added to the calendar. We verified
on a live stack that the reported flow actually succeeds end-to-end on current
code — the invitation viewer offers the action buttons, `accept` and
`addToCalendar` both return 204 and store the event (with the RFC-default
NEEDS-ACTION status applied), and a CalDAV PUT of the same payload returns 201;
the audit shows SOGo matches attendees by email and only ever special-cases
non-default ROLE/PARTSTAT values. This non-regression is now locked by unit
tests (`test_attendeeWithoutRoleAndPartStatStaysInvitable`).

The audit did surface one genuine mishandling of the missing ROLE on the
reporter's platform axis (ActiveSync): the EAS `Attendee_Type` mapping
compared the raw ROLE, so an absent ROLE was serialized as type 2 ("optional"
attendee) instead of the RFC 5545 §3.2.16 default REQ-PARTICIPANT (type 1,
"required") — making Outlook render the invited user as optional on the synced
meeting. This PR adds `-[iCalPerson roleWithDefault]` mirroring the existing
`partStatWithDefault` and uses it for the wire mapping; explicit
OPT-PARTICIPANT/NON-PARTICIPANT roles are unchanged, and wire-format tests
cover both branches plus the NEEDS-ACTION status default.
