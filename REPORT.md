# Fix for Mantis 0006193 — recurrence editor saves custom repeats on top of the previous rule

Branch: `fix-6193-mantis` (worktree `wt/c10-6193`), based on `experimental`.

## Root cause (file:line)

`SoObjects/Appointments/iCalRepeatableEntityObject+SOGo.m` — `setAttributes:inContext:`,
the server-side handler of the Angular editor's JSON save payload (`POST
/SOGo/so/<user>/Calendar/<cal>/<id>/save`):

- Lines 237–257 (CUSTOM branch): when the UI sends `repeat.frequency == "custom"`, the
  method removes the previous **RDATEs** (`removeAllRecurrenceDates`) and adds the new
  ones, but never removes the previous **RRULE**. Since `frequency` stays 0 in that
  branch, the `if (frequency)` block that would replace the rules (`setRecurrenceRules:`)
  is never reached either. A pre-existing weekly event therefore keeps
  `RRULE:FREQ=WEEKLY;COUNT=2;BYDAY=FR` **and** gains `RDATE;VALUE=DATE:...` — exactly the
  ICS attached to the ticket.
- Lines 307–312 (rule branch): the mirror bug — switching from custom back to a
  rule-based frequency replaces the RRULE but never drops the stale RDATEs.
- Display facet: `attributesInContext:` (same file, lines 172–186) overwrites the whole
  `repeat` dictionary with `{dates: [...]}` as soon as RDATEs exist, so the editor only
  ever shows the custom dates of a mixed event — the RRULE is invisible and uneditable,
  which is what the reporter observed ("editing the events again, only the custom events
  are shown").

Reproduced live on the e2e stack (read/write repro, artifacts cleaned up): PUT an ICS
with `RRULE:FREQ=WEEKLY;COUNT=2;BYDAY=FR`, POST the editor save payload with
`frequency: "custom"` → stored event contains **both** RRULE and RDATE; POST back a
weekly payload → stale `RDATE;VALUE=DATE:20260424` survives next to the RRULE.

This is a genuine bug, not a workaround candidate: the two recurrence kinds must be
mutually exclusive when saved from the web editor (the UI model — a single frequency
selector plus an optional date list — cannot represent both, and the ticket itself
proposes "the weekly repeats should be removed [...] on adding the custom repeats").

## What changed (before/after)

`SoObjects/Appointments/iCalRepeatableEntityObject+SOGo.m`, 2 added lines:

- CUSTOM branch: added `[self removeAllRecurrenceRules];` before
  `removeAllRecurrenceDates` — saving a custom repeat now drops the previous rule
  instead of merging with it.
- Rule branch: added `[self removeAllRecurrenceDates];` before `setRecurrenceRules:` —
  saving a rule-based repeat now drops the previous custom dates.

AVANT (weekly event saved as custom — bug 6193):

```
RRULE:FREQ=WEEKLY;COUNT=2;BYDAY=FR
RDATE;VALUE=DATE:20260425
```

APRÈS:

```
RDATE;VALUE=DATE:20260425
```

APRÈS (reverse direction, custom → weekly, also fixed):

```
RRULE:FREQ=WEEKLY;COUNT=2;BYDAY=FR
```

No DAV/CalDAV path is affected: `setAttributes:inContext:` is only called from
`UIxComponentEditor setAttributes:` (web editor save). Legacy events already carrying
both an RRULE and RDATEs (created by older versions) are self-healed on their next save
from the editor.

## Tests

New `Tests/Unit/TestiCalRepeatableEntityObject+SOGo.m` (registered in
`Tests/Unit/GNUmakefile`, which also builds the `Appointments` wobundle in its
`before-all` hook, following the existing Contacts/Mailer pattern):

- `test_saveCustomRepeatRemovesRecurrenceRule` — weekly RRULE + custom save → no RRULE,
  exactly one RDATE (ticket scenario).
- `test_saveCustomRepeatOnMixedEventRemovesRecurrenceRule` — legacy mixed event
  (RRULE + RDATE) + custom save → rule dropped, dates replaced.
- `test_saveRuleRepeatRemovesRecurrenceDates` — RDATE-only event + weekly save → no
  RDATE, one weekly RRULE.

The test file loads `SoObjects/Appointments/Appointments.SOGo` at runtime (same pattern
as `TestSOGoDraftObject` with the Mailer bundle) and calls the category method on parsed
`iCalEvent`s.

Suite result: `Ran 70 tests — FAILED (2 failures)`, the two failures being the
documented host-noise tests (`test_NGInternetSocketAddressFromString`,
`test_stringWithoutHTMLInjection`). With the fix reverted the 3 new tests fail; with the
fix they pass.

## Verification steps for the orchestrator

Requires a stack built from this branch (deploys are orchestrator-only; sub-agent
verified the *bug* live and the fix via unit tests).

```bash
# 1. Unit suite (from the repo root)
local/run-worktree-tests.sh ~/Projets/hadrienblanc/sogo/wt/c10-6193

# 2. Live scenario against the rebuilt stack
J=/tmp/cj; rm -f $J
curl -s -c $J -X POST -H 'Content-Type: application/json' \
  -d '{"userName":"sogo-tests1","password":"sogo"}' http://127.0.0.1:50001/SOGo/connect

curl -s -u sogo-tests1:sogo -X PUT -H 'Content-Type: text/calendar' --data-binary \
'BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:test-6193-weekly-to-custom
SUMMARY:test-6193
RRULE:FREQ=WEEKLY;COUNT=2;BYDAY=FR
DTSTART;VALUE=DATE:20260424
DTEND;VALUE=DATE:20260425
END:VEVENT
END:VCALENDAR' \
  http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/personal/test-6193-weekly-to-custom.ics \
  -o /dev/null -w 'PUT %{http_code}\n'

# edit-all-occurrences -> custom (payload identical to the Angular editor)
curl -s -b $J -X POST -H 'Content-Type: application/json' -d \
'{"isAllDay":true,"startDate":"2026-04-24","startTime":"00:00","endDate":"2026-04-25","endTime":"00:00","summary":"test-6193","classification":"public","repeat":{"frequency":"custom","interval":1,"dates":[{"date":"2026-04-25","time":"00:00"}]}}' \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Calendar/personal/test-6193-weekly-to-custom.ics/save

# EXPECT: no RRULE, one RDATE
curl -s -u sogo-tests1:sogo \
  http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/personal/test-6193-weekly-to-custom.ics | grep -E 'RRULE|RDATE'

# back to weekly — EXPECT: one RRULE, no RDATE
curl -s -b $J -X POST -H 'Content-Type: application/json' -d \
'{"isAllDay":true,"startDate":"2026-04-24","startTime":"00:00","endDate":"2026-04-25","endTime":"00:00","summary":"test-6193","classification":"public","repeat":{"frequency":"weekly","interval":1,"count":2,"days":[{"day":"FR"}]}}' \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Calendar/personal/test-6193-weekly-to-custom.ics/save
curl -s -u sogo-tests1:sogo \
  http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/personal/test-6193-weekly-to-custom.ics | grep -E 'RRULE|RDATE'

# editor view now round-trips the recurrence (repeat.frequency == weekly)
curl -s -b $J -H 'Accept: application/json' \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Calendar/personal/test-6193-weekly-to-custom.ics/view

# cleanup
curl -s -u sogo-tests1:sogo -X DELETE \
  http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/personal/test-6193-weekly-to-custom.ics -o /dev/null -w 'DELETE %{http_code}\n'
```

## PR body draft

When an event with a rule-based recurrence (e.g. weekly) was edited in the web editor
and switched to a "custom" recurrence (explicit date list), SOGo stored the new RDATEs
**on top of** the previous RRULE instead of replacing it. The calendar views then
displayed occurrences from both definitions, while the editor — which only receives the
custom dates in its JSON payload — showed and re-saved just the custom part, leaving the
hidden rule intact forever (bug 6193). The reverse transition was equally broken:
switching a custom recurrence back to weekly kept the stale RDATEs, and since the editor
prioritises RDATEs when rendering, the saved weekly choice did not stick on the next
edit.

AVANT — event saved as "custom" after being weekly:

```
RRULE:FREQ=WEEKLY;COUNT=2;BYDAY=FR
RDATE;VALUE=DATE:20260425
```

APRÈS — the previous recurrence definition is dropped, only what the editor sent
remains:

```
RDATE;VALUE=DATE:20260425
```

The fix makes `setAttributes:inContext:` (the web editor save path only; DAV clients
are untouched) treat the two recurrence kinds as mutually exclusive: the CUSTOM branch
now clears leftover RRULEs, and the rule-based branch clears leftover RDATEs before
installing the new rule. Events already corrupted by earlier versions are self-healed
the next time they are saved from the editor. Covered by three new unit tests in
`Tests/Unit/TestiCalRepeatableEntityObject+SOGo.m` exercising both transitions plus the
legacy mixed-state case.
