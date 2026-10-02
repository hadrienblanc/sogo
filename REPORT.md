# Ticket 6156 — ActiveSync: attendee time change on an externally organized meeting returns Status=1 while ignoring the change

Branch: `fix-6156-mantis` (worktree `wt/c13-6156`)

## Root cause (file:line)

`ActiveSync/SOGoActiveSyncDispatcher+Sync.m`, `-processSyncChangeCommand:inCollection:withType:objectsToTouch:inBuffer:` (lines ~675-712, attendee branch of `ActiveSyncEventFolder`).

When the ActiveSync user is an **attendee** of an event organized by someone else (`userIsAttendee:` — e.g. a meeting received from an external organizer, `MeetingStatus=3`), SOGo intentionally applies only the participation status / reminder via `[o changeParticipationStatus:inContext:component:]` and silently drops every other field of the `<Change>` (notably `StartTime`/`EndTime` — an attendee cannot reschedule the organizer's meeting).

However, the per-item `<Status>` emitted at the end of the loop was **hardcoded to 1 (Success)**:

```objc
[theBuffer appendFormat: @"<Status>%d</Status>", 1];
```

So Outlook believes its move succeeded, while SOGo's authoritative copy keeps the original time (re-pushed afterwards via `touch`). The device that issued the request ends up with a divergent local copy — exactly the inconsistent state in the ticket log (step 3: `<Change>… <Status>1</Status>` although `StartTime` moved from `20251029T130000Z` to `20251029T090000Z`). Per [MS-ASCMD] §Sync item status codes, the correct response is **7 — "Conflict matching the client and server object"**, which tells the client to drop its local modification and take the server version.

Secondary contributor (same file, same branch): the "no permission" `else` path (`[sogoObject touch]`) also returned Status=1 despite applying nothing.

## What changed (before/after)

### `ActiveSync/iCalEvent+ActiveSync.m` / `.h`

**Before**: the wire format of `<StartTime>`/`<EndTime>` was generated inline (twice, ~24 lines) inside `activeSyncRepresentationInContext:`, and there was no way to compare a client payload against the server's current schedule.

**After**:
- `activeSyncStartTimeInContext:` / `activeSyncEndTimeInContext:` — extract the exact existing generation logic (identical output, including the all-day / EAS < 16.0 user-timezone shift) into two reusable methods; `activeSyncRepresentationInContext:` now calls them (pure refactor, byte-identical XML).
- `hasActiveSyncScheduleChange:inContext:` (new) — parses the `StartTime`/`EndTime` strings sent by the client and compares them (as absolute instants, via `NSString(ActiveSync) -calendarDate`) against the server's current values **exactly as they were last sent to that client**. Absent/matching times → NO; moved/unparseable time → YES. Comparing through the same representation used on the wire makes the check immune to timezone/allday round-trip false positives.

### `ActiveSync/SOGoActiveSyncDispatcher+Sync.m`

**Before** (attendee event, user has responder rights or owns the folder):

```objc
[o changeParticipationStatus: …];            // BusyStatus/Reminder only; time dropped
// …
[theBuffer appendFormat: @"<Status>%d</Status>", 1];   // always Success
```

**After**:

```objc
timeChange = [(iCalEvent *)o hasActiveSyncScheduleChange: allChanges inContext: context];

if (responder-role || owner) {
  [o changeParticipationStatus: …];                     // unchanged
  if (timeChange) { itemStatus = 7; [sogoObject touch]; } // conflict + re-push authoritative copy
}
else {
  [sogoObject touch];                                    // unchanged
  if (timeChange) itemStatus = 7;
}
// …
[theBuffer appendFormat: @"<Status>%d</Status>", itemStatus];
```

- Per-item status defaults to 1 each iteration (`itemStatus`), only the attendee-with-time-change paths raise it to 7.
- In the allowed branch, the participation change (accept/decline/reminder) is still applied, then `touch` guarantees the authoritative item is re-sent to clients (the "optional Commands/Change with the authoritative server item" of the ticket).
- Organizer path (`takeActiveSyncValues`), contacts, tasks, mail: untouched (status stays 1).

Known limitation (unchanged vs. before): moving a **single occurrence** of a recurring attendee meeting (data in `Exceptions`, master times unchanged) is not detected and keeps returning 1; only master Start/End moves are flagged — which is the reported defect.

## Tests

New `Tests/Unit/TestiCalEvent+ActiveSync.m` (registered in `Tests/Unit/GNUmakefile`, which now also compiles `ActiveSync/iCalEvent+ActiveSync.m`, `NSString+ActiveSync.m`, `NSDate+ActiveSync.m` into the tool and links the Appointments bundle for the `SOGoAppointmentObject` class ref — the ActiveSync bundle itself cannot be built on the host, no libwbxml2):

- `test_representationsMatchWireFormat` — refactored start/end generation keeps the exact wire format (`20251029T130000Z` / `20251029T140000Z`), for EAS 14.1 and 16.1.
- `test_allDayRepresentationsAreMidnightBased` — all-day generation (`VALUE=DATE` fixtures).
- `test_attendeeMovingStartAndEndIsAScheduleChange` — exact ticket scenario (13:00Z→09:00Z, 14:00Z→10:00Z).
- `test_attendeeMovingEndTimeOnlyIsAScheduleChange`, `test_attendeeMovingStartTimeOnlyIsAScheduleChange` — each side independently.
- `test_echoedTimesAreNotAScheduleChange` — client resending server's times (the normal accept/tentative flow) must stay Status=1.
- `test_participationOnlyChangeIsNotAScheduleChange` — BusyStatus/Reminder-only payload must stay Status=1.
- `test_malformedClientTimeIsAScheduleChange` — unparseable client time keeps the server authoritative.
- `test_allDayEchoedTimesAreNotAScheduleChange`, `test_allDayMovedTimeIsAScheduleChange` — all-day round-trip (incl. the EAS<16.0 shift branch) has no false positives, real moves detected.

All branches of `hasActiveSyncScheduleChange` (start path, end path, both match/mismatch, nil parse, missing keys, allday-shift path) are exercised.

## Verification steps for the orchestrator

```
# full unit suite (build + run; 157 tests, only the 2 known host-noise failures:
# test_NGInternetSocketAddressFromString, test_stringWithoutHTMLInjection)
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c13-6156

# or, to eyeball the new tests specifically:
source /home/hadrienblanc/Projets/hadrienblanc/sogo/local/env.sh
cd /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c13-6156/Tests/Unit
export LD_LIBRARY_PATH="../SOPE/NGCards/obj:../SOPE/GDLContentStore/obj:../SoObjects/SOGo/SOGo.framework/Versions/Current/sogo:$LD_LIBRARY_PATH"
./obj/sogo-tests -f junit 2>/dev/null | grep -E 'ScheduleChange|MidnightBased|WireFormat'
# → 10 testcase entries, 0 failures
```

End-to-end (protocol-level) check of the Status=7 wire response requires a WBXML ActiveSync client (Outlook) against a deployed build; since deploys are orchestrator-only, the suggested post-deploy check is the ticket's own repro: accept an external `DisallowNewTimeProposal=1` meeting on an EAS account, move the meeting in Outlook, and confirm the Sync `Responses/Change/Status` is now `7` and Outlook reverts to the organizer's time.

## PR body draft

When an ActiveSync client such as Outlook changes the StartTime/EndTime of a meeting it only attends (external organizer, `MeetingStatus=3`), SOGo's Sync handler intentionally ignores the modification — an attendee cannot reschedule someone else's meeting — but still acknowledged the `<Change>` with item Status 1 (Success). Outlook then kept its local move while every other device (and the web UI) showed the organizer's time, leaving calendars inconsistent; the reporter also notes `DisallowNewTimeProposal` being lost on the requesting device, which is a symptom of the same one-sided divergence.

**AVANT** (ticket log, step 3): client sends `<StartTime>20251029T090000Z</StartTime>` for a meeting stored at `13:00Z` → response `<Responses><Change><ServerId>501E-…</ServerId><Status>1</Status></Change></Responses>`; the meeting stays at 13:00Z server-side and the requesting Outlook displays 09:00Z.

**APRÈS**: the same request is answered with `<Status>7</Status>` (MS-ASCMD "Conflict matching the client and server object"), while the allowed participation-status/reminder part of the change is still applied; the object is `touch`ed so the authoritative copy is re-pushed and the client reverts its local move. Time changes initiated by the organizer, and pure accept/decline/reminder updates from attendees, keep returning Status 1 (covered by unit tests on the new `iCalEvent(ActiveSync)` schedule-change detection, which compares the client values against the exact representation last sent by the server — no timezone or all-day false positives).
