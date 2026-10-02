# Ticket 5911 — COMPLETED field in task returns DATE instead of DATETIME

## Root cause

`takeActiveSyncValues:inContext:` wrote the EAS `DateCompleted` into the
VTODO through `[completed setDate: o]` (`ActiveSync/iCalToDo+ActiveSync.m:213`).
`-[iCalDateTime setDate:]` is the **all-day** variant
(`SOPE/NGCards/iCalDateTime.m:152` → `_setDateTime:forAllDayEntity:YES`),
which formats date-only and sets the `VALUE=DATE` parameter
(`SOPE/NGCards/iCalDateTime.m:139-140`). Every task completed or re-saved
through an Exchange ActiveSync client (Outlook, native phone mail apps) was
therefore stored as:

    COMPLETED;VALUE=DATE:20240104

which violates RFC 5545 §3.8.2.1 (COMPLETED has value type DATE-TIME and
MUST be UTC). SOGo then serves that stored content verbatim over CalDAV
(verified: PUT/GET and calendar-query REPORT round-trip stored content
unchanged), so CalDAV consumers like Home Assistant receive a DATE where the
spec mandates a DATETIME. All other SOGo writers were already correct:
`-[iCalToDo setCompleted:]` (`SOPE/NGCards/iCalToDo.m:80`) goes through
`setDateTime:` and renders `...Z`.

## What changed

- `ActiveSync/iCalToDo+ActiveSync.m:213` — `[completed setDate: o]` →
  `[completed setDateTime: o]`. The completed element carries no TZID, so
  `setDateTime:` renders UTC with the `Z` suffix, exactly like the
  `setCompleted:` path used by the web UI.

  AVANT (task completed via Outlook/EAS, then read over CalDAV):

      COMPLETED;VALUE=DATE:20240104

  APRÈS:

      COMPLETED:20240104T083500Z

  Legacy DATE-only values already in the store are normalized to a UTC
  DATE-TIME the next time the task is re-synced from the EAS device
  (`setDateTime:` drops the `VALUE=DATE` parameter).

- `Tests/Unit/TestiCalToDo+ActiveSync.m` (new) — three tests:
  completing a task from EAS values stores `20240104T083500Z` (not all-day,
  status COMPLETED); re-completing a task whose stored COMPLETED was
  DATE-only rewrites it as UTC DATE-TIME and drops `VALUE=DATE`;
  un-completing clears COMPLETED and sets IN-PROCESS.
- `Tests/Unit/GNUmakefile` — registers the test file and compiles
  `ActiveSync/iCalToDo+ActiveSync.m` into the test binary (same pattern as
  the existing `iCalEvent+ActiveSync.m`).

One-word diff; no behavior change outside the EAS task-completion path.

## Tests

`local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c33-5911`

    Ran 224 tests
    FAILED (2 failures, 0 errors)

The only failures are the documented host-noise ones
(`test_NGInternetSocketAddressFromString`, `test_stringWithoutHTMLInjection`).
Baseline before the change was 221 tests with the same 2 failures; the 3 new
tests pass with the fix and were verified to **fail against the unfixed
code** (`objects '20240104' and '20240104T083500Z' differs`).

## Verification steps for the orchestrator

1. Unit suite (builds SOPE + framework on first run):

       /home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
         /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c33-5911

   Expect `Ran 224 tests`, only the 2 known host-noise failures.

2. CalDAV round-trip sanity (read-only checks against the shared stack;
   the CalDAV layer stores/serves content verbatim — done during triage,
   nothing left behind):

       curl -s -u sogo-tests1:sogo \
         -X PUT http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/personal/test-5911-x.ics \
         -H "Content-Type: text/calendar; charset=utf-8" \
         --data-binary $'BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//test//EN\nBEGIN:VTODO\nUID:test-5911-x\nSUMMARY:5911\nSTATUS:COMPLETED\nCOMPLETED:20240104T083500Z\nEND:VTODO\nEND:VCALENDAR'
       curl -s -u sogo-tests1:sogo \
         http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/personal/test-5911-x.ics

   The EAS path itself has no e2e harness (no ActiveSync spec exists in
   `Tests/spec/`); it is covered by the unit tests, which assert the exact
   wire value written into the iCal content.

3. Cleanup afterwards:

       curl -s -o /dev/null -u sogo-tests1:sogo -X DELETE \
         http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/personal/test-5911-x.ics

## PR body draft

**fix(activesync): store task COMPLETED as UTC DATE-TIME (bug 5911)**

Tasks completed from an Exchange ActiveSync client (Outlook, native phone
apps) stored their completion date through the all-day setter of
iCalDateTime, producing `COMPLETED;VALUE=DATE:20240104` in the stored iCal
content. RFC 5545 §3.8.2.1 requires COMPLETED to be a DATE-TIME in UTC, and
SOGo serves the stored content verbatim over CalDAV — so strict clients such
as Home Assistant's CalDAV integration rejected (or mis-parsed) the property,
as reported in bug 5911.

The fix routes the EAS `DateCompleted` through the regular
`setDateTime:` setter, matching what every other SOGo writer (web UI,
`setCompleted:`) already does:

    AVANT:  COMPLETED;VALUE=DATE:20240104
    APRÈS:  COMPLETED:20240104T083500Z

Tasks re-synced from the device after the fix are normalized in place (the
`VALUE=DATE` parameter is dropped on rewrite). The CalDAV PUT/GET and REPORT
paths were verified by round-trip against a live stack both before and after
the change; only the ActiveSync writer differed.
