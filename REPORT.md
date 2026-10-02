# Cycle 35 clean-code pass

Scope: `fork/experimental~11..fork/experimental` — the net diff covering the
fixes of this cycle (99997 sieve scriptError retain, 99996 error-branch
ownership tests, 99995 nil/empty regex replacements, 6251 VLIST member email,
6247 freebusy off-hours timezone) plus the earlier PRs #53–#57 and the
cycle-33 pass already merged inside the range. Most of the range had already
been aligned by cycle 33; what remained was a handful of indentation slips
inside freshly introduced code and one duplicated test assertion.

One worktree commit: `style: align cycle diff with GNUstep conventions`.

## Changed (5 files, 37 insertions, 34 deletions — all no-op for behavior)

### 1. `UI/Contacts/UIxListEditor.m` — indentation of the 6251 lines

The bug-6251 change added the member-email defaulting block in the shared-AB
branch at columns 26/28, while every sibling statement of that same branch
(`emails = …`, `setFn:`, `setReference:`, `addCardReference:`) sits at
column 14. The new conditionals read as if nested inside a block that does
not exist.

Before:

    [cardReference setFn: [currentReference objectForKey: @"c_cn"]];
                        if (![memberEmail length] && [emails count])
                          memberEmail = [emails objectAtIndex: 0];
                        if ([memberEmail length])
                          [cardReference setEmail: memberEmail];
    [cardReference setReference: uid];

After (aligned with the branch's siblings, 14/16 — the exact levels the
pre-6251 `if ([emails count])` used):

    [cardReference setFn: [currentReference objectForKey: @"c_cn"]];
    if (![memberEmail length] && [emails count])
      memberEmail = [emails objectAtIndex: 0];
    if ([memberEmail length])
      [cardReference setEmail: memberEmail];
    [cardReference setReference: uid];

(The identical block in the `lookupContactWithName:` branch was already at
the correct depth — only the shared-AB copy slipped.)

### 2. `Tests/Unit/TestNGNetUtlilities.m` — one-column drift

The dual-stack tolerance added by c8af98e64 indents its whole block one
column right of the rest of the loop body (9 vs 8 spaces, continuations 11
vs 10). Re-aligned to the surrounding statements, comment continuation
included.

### 3. `SoObjects/SOGo/NSString+Utilities.m` — `RemoveRegexMatches` style

The 99995 helper was written with inline initializers
(`NSMutableString *result = […]`) and a K&R `while (…) {`, while its sibling
helper introduced by the same diff (`ReplaceRegexMatches`, ten lines up)
declares-then-assigns, and the file's statement braces otherwise sit on
their own line. Rewritten to declare-then-assign with the `while` brace on
the next line; logic byte-for-byte identical.

### 4. `Tests/Unit/TestSOGoFreeBusyObject.m` — duplicated assertion

`test_busyOffHoursWeekendFullyBusy` asserted
`startDate([infos objectAtIndex: 1]) == 2026-10-16 18:00` twice — once via
the `info` variable in the per-index block, then again verbatim right
before the contiguity loop (which does not depend on it). Dropped the
second copy; the anchor assertion 25 lines up keeps the meaning.

### 5. `SoObjects/Appointments/SOGoFreeBusyObject.m` — trailing whitespace

The 6247 refactor left two spaces on the blank line after the
`busyOffHoursInfosFrom:` call (`SOGoFreeBusyObject.m:350`); stripped.

## Reviewed and deliberately left alone

- **`UIxListEditor.m` duplicated email-defaulting**: the diff introduced
  the same 4-line "fall back to the first c_mail address, then setEmail:"
  snippet in two branches. Factoring it would need a helper crossing two
  structurally different blocks (folder lookup vs shared-AB payload) for
  four lines of payoff — not worth the churn. The pre-existing K&R
  `) {` / `} else {` shape of the shared-AB branch was likewise left
  untouched; only the diff-introduced lines were realigned.
- **`NGVList cardReferenceForReference:`**: `foundRef` + `break` matches
  the found-flag idiom used next door (`UIxListEditor cardReferences:contain:`).
  Called once per member in `setReferences:` (O(n·m) on list size) — fine
  for address-book lists; not worth a dictionary index.
- **`busyOffHoursInfosFrom:` double compare** in the `while` condition
  (`compare:` twice against `endDate`): inherited verbatim from the
  pre-refactor code, not introduced by the diff.
- **`SOGoSieveManager` `ASSIGN(scriptError, …)`**: correct GNUstep
  retain/release discipline on every branch, `[scriptError release]`
  paired in `sieveScriptWithRequirements:`; the defensive parentheses
  around `stringWithFormat:` arguments kept as-is.
- **`Tests/Unit/GNUmakefile`**: the six new entries sit in the file's
  existing loose groups; re-sorting would be churn with no signal.
- **`Tests/Unit/TestSOGoSieveManager.m` overlap** between the per-branch
  message tests and `test_scriptErrorOwnershipAcrossAllErrorBranches`: the
  former lock messages, the latter locks retain ownership under
  alloc/release + pool — collapsing them would weaken the ownership lock.
- **`TestNGVList.m` license header** (old Temple Street FSF address vs the
  51 Franklin Street wording of the newer files): license boilerplate is
  not worth touching in a style pass.

## Verification

- `local/run-worktree-tests.sh wt/c35-clean`: **257 tests, OK, 0 failures**
  (the fresh worktree needed the usual one-time
  `./configure --enable-debug --disable-strip --gsmake=…/local/root/…`
  first). The two known host-noise failures are themselves fixed inside
  this cycle's range (dual-stack tolerance in `TestNGNetUtlilities.m`,
  empty-template quirk routed through `RemoveRegexMatches`), so the run is
  fully green — better than the allowed ceiling of 2 noise failures.
