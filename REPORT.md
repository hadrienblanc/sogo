# Cycle-13 clean-code pass

Branch: `refactor/cycle-13` (worktree `wt/c13-clean`), over the cycle-13 diff
`1edd65b00..6918b2163` (= PRs #33–#36, bugs 6156, 6144, 6143, 6135).

Scope note: the literal `fork/experimental~11..fork/experimental` range spills
into cycles 11–12 (PRs #26–#32), which already received their own clean passes
(`94fd0dc5c`, `668068eda`); the reviewed diff is the exact set of commits the
orchestrator listed for this cycle.

## What changed

### 1. `ActiveSync/iCalEvent+ActiveSync.m` — fold duplicated start/end wire-format computation

The 6156 fix extracted the ActiveSync time serialization for reuse by
`hasActiveSyncScheduleChange:`, but landed it as two 20-line twins,
`activeSyncStartTimeInContext:` / `activeSyncEndTimeInContext:`, identical
except for `[self startDate]` vs `[self endDate]` (all-day correction,
protocol < 16.0 branch, dtstart timezone check, separator-less rendering).

Before (2 × 20 lines, copy-paste):

```objc
- (NSString *) activeSyncStartTimeInContext: (WOContext *) context
{
  NSCalendarDate *date;
  NSTimeZone *userTimeZone;

  date = [self startDate];
  if (!date)
    return nil;
  /* ... 14 identical lines: isAllDay + dtstart tz + ASProtocolVersion < 16.0 ... */
  return [date activeSyncRepresentationWithoutSeparatorsInContext: context];
}
/* same again for endDate */
```

After: one private helper next to the file's existing `_attendeeStatus:` /
`_busyStatus:` helpers, and the two public methods (kept in the header, they
are the tested API used by the dispatcher and the representation builder)
become one-liners:

```objc
- (NSString *) _activeSyncRepresentationOfDate: (NSCalendarDate *) date
                                     inContext: (WOContext *) context
{ /* single copy of the all-day / protocol adjustment */ }

- (NSString *) activeSyncStartTimeInContext: (WOContext *) context
{
  return [self _activeSyncRepresentationOfDate: [self startDate]
                                     inContext: context];
}
```

Net −18 lines; behavior identical (both twins consulted `dtstart`'s timezone,
preserved in the helper). Verified by the unchanged
`TestiCalEvent+ActiveSync.m` wire-format tests.

### 2. `Tests/Unit/TestiCalPerson+SOGo.m` — stub reuses the production lookup

`SOGoUser6144Stub` overrode `allEmails` and `hasEmail:` (the override of
`hasEmail:` is required: `SOGoUser`'s implementation reads the `allEmails`
ivar directly, bypassing the accessor). The hand-rolled 15-line
case-insensitive scan reimplemented `-[NSArray containsCaseInsensitiveString:]`
— the exact utility production `SOGoUser hasEmail:` uses.

Before: 15-line manual loop with `caseInsensitiveCompare:`.
After: `return [[self allEmails] containsCaseInsensitiveString: email];`
(+ the `<SOGo/NSArray+Utilities.h>` import). The stub now mirrors production
semantics instead of approximating them. Net −11 lines.

## Reviewed and deliberately left alone

- `SOGoActiveSyncDispatcher+Sync.m`: `itemStatus` is reset per `<Change>`
  iteration and both permission branches (responder / no-permission touch)
  set Status=7 on a time change — correct; mixed tab/space indentation of the
  inserted lines matches the immediately surrounding block.
- `NGVCard+SOGo.m`: `_simpleValueForType:` is NOT dead — still used for LDIF
  emails and URLs; the new `_valuesForType:` coexists legitimately
  (first-match vs all-matches). The fallback check now uses the hoisted
  `workPhones`/`homePhones` counts instead of re-reading the record — already
  the right shape.
- `iCalPerson+SOGo.m`: `uidForUser:` vs `uidInContext:` share only a 2-line
  fast path with different fallbacks (`uid` vs `uidInDomain:`) — factoring
  would obscure more than it saves.
- `attendeesWithoutUser:` puts the cheap `[user hasEmail:]` check before the
  manager-backed `uidInDomain:` lookup — already the perf-friendly order.
- `TestiCalPerson+SOGo.m`'s repeated `LoadAppointmentsBundle()` guards match
  the established `TestiCalEvent+SOGo.m` convention (13 repetitions there).
- The 4-line ticket-6135 HTML skeleton appears in both `TestNSString+Mail.m`
  and `TestNSData+Mail.m`; cross-file fixture sharing would add coupling for a
  tiny literal — left as is.
- `TestNSString+Mail.m` setUp loads the Contacts bundle like its sibling
  `TestNSData+Mail.m` — left (bundle load order in the shared runner makes
  removal low-value and unverifiable).

## Verification

```
local/run-worktree-tests.sh wt/c13-clean
# Ran 180 tests — FAILED (2 failures, 0 errors)
# -> test_NGInternetSocketAddressFromString   (known host noise, dual-stack localhost)
# -> test_stringWithoutHTMLInjection          (known host noise, GNUstep-base regex quirk)
```

Same 2 known host-noise failures as the pre-change tree; no new failures,
no new compiler warnings on the touched files.
