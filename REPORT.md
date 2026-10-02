# Fix report — Mantis 6247

## Ticket

bugs.sogo.nu #0006247 — `"Show time as busy outside working hours" ignores
timezones` (Web Calendar, minor, SOGo 5.12.10, reproducible always).

## Root cause (file:line)

The AJAX free/busy renderer builds its JSON day/hour keys by decomposing each
busy record's dates **in the timezone attached to the record's NSCalendarDate**
(`UI/MainUI/SOGoUserHomePage.m:212` `[currentStartDate shortDateString]` and
`:229 [currentDate hourOfDay]`).

Two producers feed it records with **different** timezones:

- Event records get the **requesting user's** timezone
  (`SoObjects/Appointments/SOGoAppointmentFolder.m:311` —
  `timeZone = [[context activeUser] userDefaults] timeZone]`, applied per
  record at `SOGoAppointmentFolder.m:869` and `:945/:969`). That is why normal
  events are correctly displayed in the viewer's timezone.
- The "busy outside working hours" generator built its records with the
  **calendar owner's** timezone (`SoObjects/Appointments/SOGoFreeBusyObject.m`,
  old lines 341–416: `timeZone = [ud timeZone]` where `ud` is the freebusy
  owner's defaults, all emitted `startDate`/`endDate` objects carried it).

So the owner's wall-clock hours (e.g. busy before 10:00 / after 18:00 in
Europe/Lisbon) were painted verbatim on the viewer's timeline (Europe/Warsaw),
ignoring the 1-hour difference — while real events were shifted. This matches
the ticket exactly and was reproduced live on the e2e stack (see Verification).

A second, closely-related edge was found while fixing: the generator's loop
anchor was built from the **viewer's** calendar day rebuilt at midnight in the
**owner's** timezone — an instant that can be *after* the requested window
start (viewer midnight = 23:00 owner-day−1), so the first off-hours block was
never clipped to the window start and the viewer's first hour(s) could show as
free.

## What changed (before/after)

`SoObjects/Appointments/SOGoFreeBusyObject.m` / `.h`:

- The off-hours generation block was extracted from
  `-fetchFreeBusyInfosFrom:to:` into a pure, unit-testable class method
  `+busyOffHoursInfosFrom:to:dayStartHour:dayEndHour:ownerTimeZone:viewTimeZone:`.
  Arithmetic (owner-tz anchoring, day iteration, weekend fill, clipping) is
  unchanged.
- BEFORE: emitted `startDate`/`endDate` records carried the owner's timezone.
  AFTER: the absolute instants are still computed from the owner's
  day-start/day-end hours in the **owner's** timezone ("busy outside
  10:00–18:00 Lisbon" stays the same period of time), but the emitted record
  dates now carry the **requesting user's** timezone — the exact convention
  used by `SOGoAppointmentFolder` for event records — via the new
  `+_viewDateForDate:inTimeZone:` helper (instant-preserving re-anchor:
  `dateWithTimeIntervalSince1970:` + `setTimeZone:`, same idiom as
  `_fixupRecord`).
- BEFORE: loop anchor = viewer's Y/M/D at midnight owner-tz. AFTER: anchor =
  midnight of the **owner-tz calendar day containing the window start**, so the
  covering block exists and gets clipped to the window start (fixes the missing
  first viewer hour).

No consumer changes were needed:

- `SOGoUserHomePage _freeBusyFromStartDate:` now decomposes off-hours records
  in the viewer's timezone, like event records — the displayed shift is
  correct.
- `iCalStringForFreeBusyInfos:` (freebusy.ifb, iCalendar output) converts
  periods to UTC from absolute instants (`iCalFreeBusy addFreeBusyFrom:to:`,
  SOPE/NGCards/iCalFreeBusy.m:110–118) — unchanged output.
- Conflict detection (`SOGoAppointmentObject.m:706`) compares absolute
  instants and normalizes per-record via `timeZoneDetail` deltas — unaffected.

AVANT (viewer Europe/Warsaw queries owner Europe/Lisbon, working hours
10:00–18:00, DST: +1h): busy shown 00:00–10:00 and 18:00–24:00 **Warsaw**
(owner's wall clock used as-is).
APRÈS: busy shown 00:00–11:00 and 19:00–24:00 **Warsaw** (owner's 10:00–18:00
Lisbon correctly rendered as 11:00–19:00 Warsaw).

## Tests

- `Tests/Unit/TestSOGoFreeBusyObject.m` (new, registered in
  `Tests/Unit/GNUmakefile`): 5 tests covering every branch of the generator —
  cross-timezone shift + timezone attachment (the ticket), same-timezone
  behavior, full-weekend coverage incl. contiguity, window starting during
  off-hours (clipped start), window starting inside working hours (skipped
  morning block). DST-stable fixed dates (October 2026).
- `Tests/spec/AjaxFreeBusyOffHoursSpec.js` (new e2e): sets owner
  (sogo-tests1) to Europe/Lisbon 10:00–18:00 + busyOffHours, viewer
  (sogo-tests2) to Europe/Warsaw, calls
  `/SOGo/so/<owner>/freebusy.ifb/ajaxRead?sday=<today>&eday=<today>` and
  asserts the busy hours JSON: `0–10 ∪ 19–23` on weekdays, `0–23` on weekends;
  restores both users' preferences in `afterAll`. Runs on the rebuilt stack
  with the orchestrator's post-merge full suite.
- Full unit suite: `Ran 257 tests — OK` (known host-noise failures did not
  trigger on this run).

## Verification steps for the orchestrator

Unit (already run in this worktree):

```
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-6247
```

E2E on the rebuilt stack (expects busy hours 0–10 and 19–23 on a weekday;
before the fix this returns 0–9 and 18–22):

```
# login
curl -s -c /tmp/c1 -X POST http://127.0.0.1:50001/SOGo/connect \
  -H 'Content-Type: application/json' \
  -d '{"userName": "sogo-tests1", "password": "sogo"}'
curl -s -c /tmp/c2 -X POST http://127.0.0.1:50001/SOGo/connect \
  -H 'Content-Type: application/json' \
  -d '{"userName": "sogo-tests2", "password": "sogo"}'
# owner: Lisbon, 10:00-18:00, busy outside working hours
curl -s -b /tmp/c1 -X POST http://127.0.0.1:50001/SOGo/so/sogo-tests1/Preferences/save \
  -H 'Content-Type: application/json' \
  -d '{"defaults": {"SOGoTimeZone": "Europe/Lisbon", "SOGoDayStartTime": "10:00", "SOGoDayEndTime": "18:00", "SOGoBusyOffHours": true}}'
# viewer: Warsaw
curl -s -b /tmp/c2 -X POST http://127.0.0.1:50001/SOGo/so/sogo-tests2/Preferences/save \
  -H 'Content-Type: application/json' \
  -d '{"defaults": {"SOGoTimeZone": "Europe/Warsaw"}}'
# freebusy as seen by the viewer (weekday)
D=$(TZ=Europe/Lisbon date +%Y%m%d)
curl -s -b /tmp/c2 "http://127.0.0.1:50001/SOGo/so/sogo-tests1/freebusy.ifb/ajaxRead?sday=$D&eday=$D" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); [print(k, sorted(map(int, v.keys()))) for k, v in d.items()]'
# restore afterwards (Europe/Paris / 08:00 / 18:00 / busyOffHours false)

# jasmine spec (inside the sogo_dev container, after merge/rebuild):
cd /workspace/Tests && sed -i 's/port: "50001"/port: "50000"/' lib/config.js && \
  npx jasmine --config=spec/support/jasmine.json --filter='freebusy "busy outside working hours" (bug 6247)'
# restore lib/config.js afterwards
```

Repro artifacts created on the shared stack during investigation (preferences
of sogo-tests1/2) were restored to the stack defaults; no events named
test-6247-* remain.

## PR body draft

When a user enables "Show time as busy outside working hours", the free/busy
panel used by "Invite attendees" painted those blocks using the calendar
owner's wall-clock hours, ignoring the timezone of the person viewing the
timeline. AVANT : User 1 (Europe/Lisbon, working hours 10:00–18:00) appeared
busy before 10:00 and after 18:00 for User 2 (Europe/Warsaw) — while User 1's
actual events were correctly shifted by one hour, making the display
inconsistent. APRÈS : the off-hours blocks are still computed from the owner's
day start/end hours in the owner's timezone (the busy *periods* are
unchanged), but they are now rendered in the viewer's timezone — User 2 sees
User 1 busy before 11:00 and after 19:00 Warsaw time, consistently with the
events.

The fix aligns the off-hours records with the convention already used for
event records (dates attached to the requesting user's timezone, as done in
SOGoAppointmentFolder) and extracts the generator into a pure, unit-tested
method. It also fixes an edge found along the way: when the viewer's midnight
falls before the owner's midnight (always, for eastward viewers), the first
off-hours block could start after the requested window and the viewer's first
hour was shown as free. The iCalendar freebusy export and conflict detection
are unaffected (they work on absolute instants). Covered by new unit tests
(TestSOGoFreeBusyObject) and a new e2e spec (AjaxFreeBusyOffHoursSpec).
