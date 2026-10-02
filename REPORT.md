# Bug 6131 — Email-alarm bookkeeping fired on every calendar view for orphaned RECURRENCE-ID events

## Root cause (file:line)

`-[iCalEntityObject(SOGoExtensions) updateNextAlarmDateInRow:forContainer:nameInContainer:]`
in `SoObjects/Appointments/iCalEntityObject+SOGo.m:762`.

When an event carries a `RECURRENCE-ID` but no parent recurring event (no
`RRULE`/`RDATE` anywhere in the .ics — the exact fixture attached to the
ticket):

- `isRecurrent` is NO (it only checks `hasRecurrenceRules || hasRecurrenceDates`,
  `SOPE/NGCards/iCalRepeatableEntityObject.m:406`), so the **non-recurring**
  branch of `updateNextAlarmDateInRow` runs, yet the event is stored with
  `c_iscycle = 1` (`iCalEvent+SOGo.m:134` also checks `recurrenceId`) and
  `c_cycleinfo = NULL`.
- On every calendar view, `-[SOGoAppointmentFolder flattenCycleRecord:...]`
  hits the "vcalendar that contains ONLY one or more vevent with
  recurrence-id" path (`SOGoAppointmentFolder.m:1270-1282`) and calls
  `quickRecordsFromContent:container:nil nameInContainer:<c_name>`; the
  exception path `_appendCycleException` (`SOGoAppointmentFolder.m:1148,1160`)
  likewise passes `container:nil nameInContainer:nil`. The container is
  deliberately nil to avoid re-entrancy on the DB channel.
- `updateNextAlarmDateInRow` nevertheless acquired the email-alarms folder
  (`af`) whenever `SOGoEnableEMailAlarms = YES`, found the `ACTION:EMAIL`
  alarm, computed a `nextAlarmDate` in the past (`TRIGGER:-P1W` on a
  2025-06-28 event), set `nextAlarmDate = nil` and `email_alarm_number = 0`,
  then hit the "Delete old email alarms" branch
  (`iCalEntityObject+SOGo.m:938-940`): a call to
  `-[GCSAlarmsFolder deleteRecordForEntryWithCName:inCalendarAtPath:]` with a
  **nil** path (and a nil or non-nil name depending on the call site).
- `EOSQLQualifier` renders nil varargs as the string `NULL`
  (`SOPE/GDLAccess/EOQualifierScanner.m:108` → `[NSNull null]` → `"NULL"`),
  producing the observed, once-per-event-per-viewquery SQL:

```
DELETE FROM sogo_alarms_folder WHERE c_path='NULL' AND c_name='NULL';
DELETE FROM sogo_alarms_folder WHERE c_path='NULL' AND c_name='4C39-627DFA80-15-2FEA38C0.ics';
```

The recurring-event branch of the same method already guarded itself with
`if (theContainer)` ("reentrant" check, `iCalEntityObject+SOGo.m:838`); the
non-recurring EMAIL branch and the trailing delete had no such guard. The same
unguarded path could also `SELECT`/`INSERT` garbage rows (`c_path='NULL'`)
for future-dated email alarms on every view.

This is a genuine bug (not a data-only issue): importing the ticket's .ics into
a stock SOGo with email alarms enabled triggers the malformed SQL on every
calendar fetch.

## What changed (before/after)

One condition, one file (`SoObjects/Appointments/iCalEntityObject+SOGo.m:762`):

```diff
-  if ([[SOGoSystemDefaults sharedSystemDefaults] enableEMailAlarms])
+  if ([[SOGoSystemDefaults sharedSystemDefaults] enableEMailAlarms]
+      && theContainer)
```

- BEFORE: with `SOGoEnableEMailAlarms = YES`, view/flatten calls (container
  deliberately nil) still opened the alarms folder and issued
  `DELETE ... WHERE c_path='NULL' AND c_name='NULL'` (or with the .ics name)
  once per problematic event per fetch — a month view listing N such events
  issued N useless DELETEs (reported ~2 s vs 0.2 s).
- AFTER: the alarms-folder handle is only acquired when a real container is
  present (i.e. on the save path, `GCSFolder.m:1049`, and in the ealarms
  notifier, `Tools/SOGoEAlarmsNotifier.m:289`). With `af = nil`, the EMAIL
  branch at line 800 is skipped, `email_alarm_number` stays -1 and the delete
  at line 938 can no longer fire — flatten/view never touches
  `sogo_alarms_folder` again. Legitimate save-path behaviour (single
  `writeRecord`/`deleteRecord` with real `c_path`/`c_name`) is unchanged, as
  is the `SOGoEnableEMailAlarms = NO` behaviour.

## Tests

New `Tests/Unit/TestiCalEntityObjectEmailAlarms.m` (registered in
`Tests/Unit/GNUmakefile`). It overrides the three `GCSAlarmsFolder` record
methods with a recording category (no DB) and uses a minimal fake container
exposing `ocsPath`:

- `test_emailAlarmsFolderUntouchedWithoutContainer` — ticket fixture
  (orphaned `RECURRENCE-ID` + past `ACTION:EMAIL` alarm), container nil,
  name nil → zero alarms-folder calls, `c_nextalarm` reset to 0.
- `test_emailAlarmsFolderUntouchedWithoutContainerAndWithName` — same but
  name set (the `flattenCycleRecord` variant that produced
  `c_path='NULL' AND c_name='4C39-....ics'`) → zero calls.
- `test_expiredEmailAlarmDeletedWithContainer` — real container + name →
  exactly one `delete` with the container coordinates (save path preserved).
- `test_emailAlarmsFolderUntouchedWhenDisabled` — alarms disabled → zero
  calls.

Red/green proof: with the one-line fix reverted, the two first tests fail with
`got: ({op = delete; })` / `got: ({cname = "test-6131-orphan.ics"; op = delete; })`
— i.e. the exact malformed DELETEs of the ticket. With the fix, 188 tests ran
with only the two known host-noise failures (`test_NGInternetSocketAddressFromString`,
`test_stringWithoutHTMLInjection`).

## Verification steps for the orchestrator

```bash
# unit suite (build + run) — expect only the 2 known host failures
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
  /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c14-6131

# optional e2e sanity on the shared stack (alarms disabled there; exercises
# import + flatten + view of the orphaned occurrence — artifacts cleaned up)
cp <ticket ics> /tmp/opencode/test-6131-pb-sogo.ics
curl -s -o /dev/null -w "%{http_code}\n" -u sogo-tests1:sogo -X MKCOL \
  "http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/test-6131-cal/"            # 201
curl -s -o /dev/null -w "%{http_code}\n" -u sogo-tests1:sogo -X PUT \
  -H "Content-Type: text/calendar; charset=utf-8" \
  --data-binary @/tmp/opencode/test-6131-pb-sogo.ics \
  "http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/test-6131-cal/test-6131-orphan.ics"  # 201
curl -s -o /dev/null -w "%{http_code}\n" -X REPORT -H "Depth: 1" \
  -H "Content-Type: application/xml" -u sogo-tests1:sogo \
  --data '<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav"><D:prop><D:getetag/></D:prop><C:filter><C:comp-filter name="VCALENDAR"><C:comp-filter name="VEVENT"><C:time-range start="20250601T000000Z" end="20250731T000000Z"/></C:comp-filter></C:comp-filter></C:filter></C:calendar-query>' \
  "http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/test-6131-cal/"            # 207
curl -s -o /dev/null -w "%{http_code}\n" -u sogo-tests1:sogo -X DELETE \
  "http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/test-6131-cal/test-6131-orphan.ics"  # 204
curl -s -o /dev/null -w "%{http_code}\n" -u sogo-tests1:sogo -X DELETE \
  "http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/test-6131-cal/"            # 204
```

(Reproducing the DELETEs live requires a stack with `SOGoEnableEMailAlarms=YES`
+ `OCSEMailAlarmsFolderURL` and SQL logging; the shared e2e stack has email
alarms off, hence the deterministic unit red/green as the proof.)

## PR body draft

With `SOGoEnableEMailAlarms = YES`, calendars containing an orphaned
recurrence exception (a VEVENT with `RECURRENCE-ID` but no parent recurring
event — see the .ics attached to bug 6131) triggered one malformed SQL
statement per event on **every view/fetch**:

AVANT (per problematic event, each time the calendar is displayed):

```
DELETE FROM sogo_alarms_folder WHERE c_path='NULL' AND c_name='NULL';
DELETE FROM sogo_alarms_folder WHERE c_path='NULL' AND c_name='4C39-627DFA80-15-2FEA38C0.ics';
```

Such events are stored with `c_iscycle=1` but no `c_cycleinfo`, so
`flattenCycleRecord` rebuilds their quick record on each fetch while
deliberately passing a nil container (re-entrancy guard). The email-alarm
bookkeeping in `updateNextAlarmDateInRow:forContainer:nameInContainer:`
ignored that nil container: it still opened the alarms folder, classified the
past `ACTION:EMAIL` alarm as expired, and issued the trailing
"delete old email alarms" call with nil `c_path`/`c_name`, which
`EOSQLQualifier` renders as the literal string `'NULL'`. Users reported month
views taking ~2 s instead of 0.2 s, and future-dated alarms could equally
`SELECT`/`INSERT` `c_path='NULL'` garbage rows on every view.

APRÈS, the alarms-folder handle is only acquired when a real container is
provided — i.e. on the save path and in the ealarms notifier — so viewing a
calendar never writes to or deletes from `sogo_alarms_folder` again, while
saving an event with an expired email alarm still cleans its record exactly
once with the correct `c_path`/`c_name`. The fix is a single `&& theContainer`
guard on the handle acquisition; behaviour with `SOGoEnableEMailAlarms = NO`
is unchanged. New unit tests (`Tests/Unit/TestiCalEntityObjectEmailAlarms.m`,
no DB required) lock both directions: zero alarms-folder calls when flattening
with a nil container (both `c_name` variants of the ticket), and the preserved
single delete on the save path — they fail on the pre-fix code with the exact
malformed calls of the ticket.
