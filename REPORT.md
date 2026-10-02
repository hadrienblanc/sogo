# Ticket 6162 — Creating a calendar event with recurrence according to RFC 5545

Branch: `fix-6162-mantis` (commit `b58bd1991`), based on `experimental`.

## Root cause (file:line)

Two facts combine into the reported symptom:

1. **Expansion always force-includes DTSTART.**
   `SOPE/NGCards/iCalWeeklyRecurrenceCalculator.m:180-185` — when the walk cursor
   equals the first-instance start (DTSTART), the occurrence is added
   unconditionally, bypassing the BYDAY check at lines 188-192:
   ```objc
   if ([currentStartDate compare: firStart] == NSOrderedSame)
     {
       // Always add the start date of the recurring event if within
       // the lookup range.
       isRecurrence = YES;
     }
   ```
   This is RFC-sanctioned ("DTSTART defines the first instance"; a
   non-synchronized DTSTART yields an *undefined* set), and it is required for
   interoperability with foreign imports — `Tests/Unit/TestiCalRecurrenceCalculator.m`
   (RFC 2445 example, Tuesday DTSTART with `BYDAY=MO,WE,FR`) depends on it.
   So the calculator must **not** be changed.

2. **The web-UI save path never synchronized DTSTART with BYDAY.**
   `UI/Scheduler/UIxAppointmentEditor.m:568` → `UIxComponentEditor.m:614` →
   `SoObjects/Appointments/iCalEvent+SOGo.m setAttributes:inContext:` wrote the
   user's DTSTART and the RRULE (`iCalRepeatableEntityObject+SOGo.m:294-312`)
   as two independent values. When the user created a weekly MO,FR,SA event
   starting Wednesday, SOGo stored `DTSTART=Wednesday` — and fact #1 then made
   the Wednesday "ghost occurrence" appear in every view.

The bug therefore lives in the **save path**, and per the ticket the fix is to
snap DTSTART forward to the first BYDAY-matching day when the event is saved.

AVANT reproduction (pre-fix code, shared stack, artifact cleaned up):

```
PUT /SOGo/dav/sogo-tests1/Calendar/personal/test-6162-avant.ics  (ticket ICS:
     DTSTART;TZID=Europe/Moscow:20251001T094500, RRULE:FREQ=WEEKLY;BYDAY=MO,FR,SA;UNTIL=20251015T144500Z)
REPORT calendar-query time-range 20251001T000000Z..20251002T000000Z
  -> returns the event  (an occurrence exists on Wednesday Oct 1 — wrong)
```

## What changed (before/after)

Minimal change, 3 files, confined to the SOGo web-editor save path
(CalDAV PUT / imports are untouched and keep storing exactly what the client sent):

- `SoObjects/Appointments/iCalEvent+SOGo.h` — declare
  `- (void) synchronizeStartDateWithRecurrenceRule`.
- `SoObjects/Appointments/iCalEvent+SOGo.m` — implement it and call it from
  `setAttributes:inContext:` (right after DTSTART/DTEND are written, so the
  follow-up `_adjustRecurrentRules` in `UIxAppointmentEditor saveAction`
  re-validates UNTIL and prunes orphaned overrides against the snapped dates):
  - skipped for occurrences (`recurrenceId`), events without rules,
    non-weekly rules, weekly rules without BYDAY, and empty/unparsable BYDAY;
  - skipped when the start weekday already matches BYDAY;
  - otherwise scans forward 1..6 days for the first weekday in the BYDAY mask
    and shifts DTSTART/DTEND by the same whole days (duration preserved);
    all-day events are rewritten via `setAllDayWithStartDate:duration:` so
    `VALUE=DATE` is preserved; timed events keep their timezone.

AVANT (stored ICS after creating "weekly on MO,FR,SA" starting Wed Oct 1):

```
DTSTART;TZID=Europe/Moscow:20251001T094500
DTEND;TZID=Europe/Moscow:20251001T144500
RRULE:FREQ=WEEKLY;BYDAY=MO,FR,SA;UNTIL=20251015T144500Z
```
-> expansion force-includes Wed Oct 1 (ghost occurrence).

APRES (same user action):

```
DTSTART;TZID=Europe/Moscow:20251003T094500
DTEND;TZID=Europe/Moscow:20251003T144500
RRULE:FREQ=WEEKLY;BYDAY=MO,FR,SA;UNTIL=20251015T144500Z
```
-> DTSTART now matches BYDAY (nearest upcoming match, Friday Oct 3), exactly
the behavior requested in the ticket; occurrences are Fri Oct 3, Sat Oct 4,
Mon Oct 6, Fri Oct 10, Sat Oct 11, Wed Oct 15 excluded.

## Tests

New `Tests/Unit/TestiCalEvent+SOGo.m` (registered in `Tests/Unit/GNUmakefile`),
12 tests covering every branch of the new method plus the `setAttributes:`
call site:

- `test_synchronizeStartDateOnNonMatchingWeeklyByDay` — ticket scenario: Wed
  Oct 1 + MO,FR,SA -> Fri Oct 3 09:45/14:45 (Moscow);
- `test_synchronizeStartDateKeepsMatchingStartDate` — WE in BYDAY -> unchanged;
- `test_synchronizeStartDateOnAllDayEvent` — `VALUE=DATE` preserved,
  DTSTART/DTEND shifted, still all-day;
- `test_synchronizeStartDateCrossesWeekBoundary` — Sat Oct 4 + BYDAY=TU ->
  Tue Oct 7;
- `test_synchronizeStartDateIgnoresDailyRule` — non-weekly frequency guard;
- `test_synchronizeStartDateIgnoresWeeklyRuleWithoutByDay` — nil-mask guard;
- `test_synchronizeStartDateOnEventWithoutRecurrenceRule` — no-rule guard;
- `test_synchronizeStartDateOnUnparsableByDay` — `BYDAY=XX` (empty mask, delta
  stays 0) -> unchanged;
- `test_synchronizeStartDateOnOccurrence` — VEVENT with RECURRENCE-ID -> never
  snapped;
- `test_saveWeeklyRepeatSnapsTimedStartDate` — full editor save path (timed):
  DTSTART/DTEND snapped to Friday, `doesOccurOnDate` NO on Oct 1 / YES on Oct 3;
- `test_saveWeeklyRepeatKeepsMatchingStartDate` — full save path, matching rule;
- `test_saveWeeklyRepeatSnapsAllDayStartDate` — full save path (all-day).

Result: `Ran 145 tests — FAILED (2 failures, 0 errors)` where the 2 failures
are the known host-noise ones to ignore (`test_NGInternetSocketAddressFromString`,
`test_stringWithoutHTMLInjection`). The pre-existing weekly-calculator test
(RFC example) still passes.

## Verification steps for the orchestrator

Unit suite (authoritative — the shared stack runs a pre-fix build until the
next deploy/rebuild):

```
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
  /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c12-6162
# expect: Ran 145 tests, only the 2 known host-noise failures

# optional: list the new tests + their status
cd /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c12-6162/Tests/Unit
source /home/hadrienblanc/Projets/hadrienblanc/sogo/local/env.sh
export LD_LIBRARY_PATH="$PWD/../../SOPE/NGCards/obj:$PWD/../../SOPE/GDLContentStore/obj:$PWD/../../SoObjects/SOGo/SOGo.framework/Versions/Current/sogo:$LD_LIBRARY_PATH"
./obj/sogo-tests -f junit 2>/dev/null | grep -E 'test_(synchronize|saveWeekly)'
# 15 lines (12 new + 3 pre-existing save* tests), none containing <failure>
```

Live AVANT symptom on the shared stack (read/write repro only, artifact
`test-6162-avant` deleted afterwards):

```
curl -s -u sogo-tests1:sogo -X PUT -H "Content-Type: text/calendar" \
  --data-binary $'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:test-6162-avant\r\nSUMMARY:Test\r\nDTSTART;TZID=Europe/Moscow:20251001T094500\r\nDTEND;TZID=Europe/Moscow:20251001T144500\r\nRRULE:FREQ=WEEKLY;BYDAY=MO,FR,SA;UNTIL=20251015T144500Z\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n' \
  "http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/personal/test-6162-avant.ics" -o /dev/null -w "%{http_code}\n"   # 201

curl -s -u sogo-tests1:sogo -X REPORT -H "Depth: 1" -H "Content-Type: application/xml" \
  --data-binary '<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav"><D:prop><D:getetag/></D:prop><C:filter><C:comp-filter name="VCALENDAR"><C:comp-filter name="VEVENT"><C:time-range start="20251001T000000Z" end="20251002T000000Z"/></C:comp-filter></C:comp-filter></C:filter></C:calendar-query>' \
  "http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/personal/" | grep test-6162-avant   # present on Wednesday (bug)

curl -s -u sogo-tests1:sogo -X DELETE \
  "http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/personal/test-6162-avant.ics" -o /dev/null -w "%{http_code}\n"  # 204 (cleanup)
```

After this branch is deployed to the e2e stack, the same check through the web
editor (`POST /SOGo/so/<user>/Calendar/personal/<uid>/saveAsAppointment` with
`repeat:{frequency:"weekly",interval:1,days:[{day:"MO"},{day:"FR"},{day:"SA"}]}`,
`startDate/endDate:"2025-10-01"`, `startTime:"09:45"`, `endTime:"14:45"`) must
store `DTSTART;TZID=...:20251003T...` and the Oct 1 time-range REPORT above
must return nothing.

## PR body draft

When a user creates (or re-saves) a weekly recurring event whose start date
does not fall on one of the weekdays selected in the recurrence dialog, SOGo
used to store DTSTART as-is and then render an occurrence on that weekday
anyway — e.g. an event created on Wednesday, October 1 with "weekly on Monday,
Friday, Saturday" showed up on Wednesday, although Wednesday is not part of the
rule. RFC 5545 requires DTSTART to be synchronized with BYDAY, and states that
the recurrence set generated from a non-synchronized DTSTART is undefined, so
the stored data was both invalid and misleading.

**AVANT** — the user creates an event on 2025-10-01 (Wednesday) with weekly
recurrence on MO,FR,SA; SOGo stores:

```
DTSTART;TZID=Europe/Moscow:20251001T094500
DTEND;TZID=Europe/Moscow:20251001T144500
RRULE:FREQ=WEEKLY;BYDAY=MO,FR,SA;UNTIL=20251015T144500Z
```

and an occurrence incorrectly appears on Wednesday Oct 1.

**APRES** — the same user action now snaps DTSTART (and DTEND, duration
preserved) forward to the nearest upcoming BYDAY match before saving:

```
DTSTART;TZID=Europe/Moscow:20251003T094500
DTEND;TZID=Europe/Moscow:20251003T144500
RRULE:FREQ=WEEKLY;BYDAY=MO,FR,SA;UNTIL=20251015T144500Z
```

so the series runs Fri Oct 3, Sat Oct 4, Mon Oct 6, Fri Oct 10, Sat Oct 11 and
no occurrence exists outside the rule. The synchronization happens in the
web-editor save path (`iCalEvent+SOGo setAttributes:inContext:` → new
`synchronizeStartDateWithRecurrenceRule`), only for weekly rules carrying a
BYDAY list, never for occurrence overrides, and CalDAV imports keep storing
exactly what the client sent. Backed by 12 new unit tests in
`Tests/Unit/TestiCalEvent+SOGo.m` covering every guard branch (non-weekly
rules, no BYDAY, unparsable BYDAY, matching weekday, week-boundary wrap,
all-day events, occurrences) plus the full `setAttributes` save path.
