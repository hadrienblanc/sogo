# Cycle 33 clean-code pass

Scope: `fork/experimental~11..fork/experimental` (PRs #46–#56: bugs 6153,
6152, 6142, 6133, 6129, 5911, 5910, 5909, 5908, plus the cycle-15/16
reports). The cycle is overwhelmingly additive tests plus four small
production changes (`iCalToDo+ActiveSync.m`, `iCalTimeZonePeriod.m`,
`SOGoMailFolder.m`, `NSString+ActiveSync.{h,m}` +
`SOGoActiveSyncDispatcher+Sync.m`). One worktree commit:
`03c6c1d63 style: align cycle diff with GNUstep conventions`.

## Changed (3 files, 8 insertions, 9 deletions)

### 1. `ActiveSync/SOGoActiveSyncDispatcher+Sync.m` — continuation indent

The bug-5909 call site wrapped its log argument at only +2 columns under the
statement, making the continuation read like a sibling statement inside the
`else if` block. Every wrapped `logWithFormat:`/message-send precedent in
the tree indents continuations well past the statement (e.g.
`SoObjects/Appointments/SOGoAppointmentFolders.m:533`,
`SoObjects/Mailer/SOGoMailObject.m:1324`).

Before:

    [self logWithFormat: @"%@",
      [NSString activeSyncCacheCleanupLogMessageForDevice: [context objectForKey: @"DeviceId"]
      ...

After (+4 on the whole argument, selector colons kept aligned):

    [self logWithFormat: @"%@",
          [NSString activeSyncCacheCleanupLogMessageForDevice: [context objectForKey: @"DeviceId"]
          ...

### 2. `SoObjects/Mailer/SOGoMailFolder.m` — detached nil assignment

The bug-6153 rewrite declared `NSException *error;` and then assigned
`error = nil;` two lines later, adding a no-op statement between declaration
and use. The file already uses inline initialization (`SOGoMailFolder.m:1292`
`NSException *error = nil;`). Merged into one line; behavior identical.

### 3. `Tests/Unit/TestiCalToDo+ActiveSync.m` — in-file consistency

- line 113 used `testWithMessage(!...)` while the four other calls in the
  same file use `testWithMessage (...)` — normalized (message continuation
  re-aligned);
- `_context` had a stray double space: `setObject: @"16.1"  forKey:` → single.

## Reviewed and deliberately left alone

- **`NSString+ActiveSync` log-message helper (5909)**: an NSString-category
  class method is an unusual home for a dispatcher log string, but it is what
  makes the exact message lockable by `TestNSString+ActiveSync.m`; the
  declarations are colon-aligned and the tests are fine. Redesigning it now
  would churn a merged, tested fix for zero behavior gain.
- **`SOPE/NGCards/iCalTimeZonePeriod.m` (6133)**: the fix *removed* a
  duplicated `_occurrenceForDate:byRRule:` computation (the one real perf
  smell of the cycle); the resulting `else` chain has no dead code.
- **`Tests/Unit/GNUmakefile`**: the added `-I../../` looks broad but is
  required — `UI/MailPartViewers/UIxMailRenderingContext.m`, newly compiled
  into the tool, imports `<SoObjects/Mailer/SOGoMailAccount.h>`, which only
  resolves from the repo root. Test-file additions are grouped consistently
  with the surrounding list; the odd comment at lines 80–81 predates the
  cycle (`d902756aa`) and stays out of scope.
- **`TestApacheAliasDirectives.m`**: `ApacheAliasMatches()` mirrors Apache's
  `alias_matches()` verbatim, including its `aliasp[-1]` idiom — intentional
  fidelity for locking AH00671 semantics, not local dead code. The O(n²)
  overlap scan runs on ~2 aliases. Parsing/tokenizing helpers are single-use
  and clear.
- **Fixtures**: no duplication worth factoring. The three 6152 tests cover
  distinct layers (body-part classification, HTML extraction, viewer
  selection) with minimal distinct payloads; the JS spec necessarily carries
  its own RFC 2822 message. The three VTIMEZONE calendars in
  `TestiCalTimeZoneFallback.m` exercise different rule shapes (RDATE-only,
  expired RRULE, open-ended RRULE). `TestNSString+ActiveSync.m`'s two tests
  share shape but differ in data — clearer than a parameterized helper of
  equal length.
- **Test macro spacing** (`test (...)` vs `test(...)`) varies across the
  pre-existing suite; every new file is internally consistent except the one
  line fixed above. Not worth cross-file normalization.
- **No comments were added**; the existing `/* bug NNNN: ... */` test
  comments came with the merged fixes and carry bug context.

## Verification

`local/run-worktree-tests.sh wt/c33-clean` → **234 tests, 2 failures** —
exactly the two known host-noise failures
(`test_NGInternetSocketAddressFromString`, `test_stringWithoutHTMLInjection`),
i.e. no worse than baseline. (Fresh worktree needed the usual
`./configure --enable-debug --disable-strip` first; `config.make` is
untracked and not committed.)

Nothing else in the cycle diff met the bar for touching; the smallest safe
change here was almost no change.
