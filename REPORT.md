# Ticket 99996 — sogo-tests: 7 GSCInlineString still over-released during the run

Branch: `fix-99996-mantis`

## Verdict: NOT A BUG in the current source — stale-build artifact in the main checkout

The current tree (experimental @ 61e70aefb, including PR #59) has **zero**
over-releases: a from-scratch build of the unit suite runs 248 tests, `OK`,
exit code 0, and `NSZombieEnabled=YES` logs **0** `message sent to
deallocated instance`. The "7 GSCInlineString" observed by the reporter are
the *pre-#59* SOGoSieveManager `scriptError` over-releases, served by a
**stale `libSOGo.so`** in the main checkout. A regression test is added so
that this class of staleness/regression now trips *inside* the suite instead
of silently at process exit.

## Root cause (file:line) — of the observed symptom

- The 7 zombies were dumped under gdb (`GSLogZombie`, breakpoint at
  libgnustep-base+0x1714e0) by running the **main checkout's** binary:
  `cd sogo/Tests/Unit && NSZombieEnabled=YES ./obj/sogo-tests` → rc=1, 7x
  `-[GSCInlineString release]: message sent to deallocated instance`.
  Their contents are all SOGoSieveManager `scriptError` strings:
  `Rule based on unknown field 'bogus'`, `Rule has unknown operator 'bogus'`,
  `Action has unknown method 'bogusmethod'`,
  `Action with invalid flag argument 'bogus'` (x2), `Bad test: bogus`,
  `Test 'all' used without any specified rule` — exactly the branches
  exercised by the 13 tests added in PR #59.
- Main checkout build state (read-only inspection):
  `SoObjects/SOGo/obj/SOGo.obj/SOGoSieveManager.m.o` mtime **08:08**,
  `libSOGo.so.5.12.11` linked **10:23:35**, while PR #59 (the ASSIGN fix,
  `SoObjects/SOGo/SOGoSieveManager.m`) merged at **10:40-10:41** and the test
  objects relinked at **10:47**. The orchestrator therefore ran the *new*
  `TestSOGoSieveManager` tests against the *old* framework: every error
  branch stored a non-owned string in `scriptError` and the manager `dealloc`
  over-released it (the exact bug fixed by PR #59, former lines 348/388/538/
  566/630/636 of `SoObjects/SOGo/SOGoSieveManager.m`).
- Same staleness explains the reporter's `test_stringWithoutHTMLInjection`
  failure: `NSString+Utilities.m.o` (08:08) also predates PR #57's
  `RemoveRegexMatches` (10:15); a fresh build passes that test.
- Reproduced the symptom end-to-end in this worktree by temporarily
  restoring the pre-#59 `SOGoSieveManager.m` (from 30653474a) and rebuilding:
  without zombies → `Segmentation fault (core dumped)` rc=139 (the ticket's
  crash); with `NSZombieEnabled=YES` → 13 over-release messages, of which
  **exactly 7** at the final pool drain of `main` (Tests/Unit/sogo-tests.m:128)
  — the ticket's repro, bit for bit. Restored afterwards; the tree is clean.

## What changed (before/after)

No production code change (nothing to fix in source).

`Tests/Unit/TestSOGoSieveManager.m` — new test
`test_scriptErrorOwnershipAcrossAllErrorBranches` (file already registered in
`Tests/Unit/GNUmakefile`):

- **AVANT**: the PR-#59 tests trigger one error branch each on an
  *autoreleased* manager; an over-releasing (stale or regressed) libSOGo only
  trips at the *process-exit* pool drain — silent unless someone runs with
  `NSZombieEnabled=YES`.
- **APRES**: the new test drives **all six** direct-extractor error branches
  inside one dedicated `NSAutoreleasePool`, with a **retained** manager
  (holding a `stringWithFormat:`-created `scriptError`) released before the
  pool drains. Against the pre-#59 code the 6 corpses trip **during the
  suite**, right at this test (verified on the temporary pre-#59 rebuild);
  against the current code it passes cleanly and asserts `lastScriptError`
  for each branch.

## Tests

`Tests/Unit/TestSOGoSieveManager.m`:
`test_scriptErrorOwnershipAcrossAllErrorBranches` — covers the
ownership/dealloc path of `scriptError` for the six direct extractor error
branches (unknown field, unknown operator, unknown action method, invalid
flag argument, bad test, match-without-rule), which is precisely the code the
ticket's 7 zombies came from.

## Verification steps for the orchestrator

```bash
# 0. (context) the reporter's repro on the main checkout — stale libSOGo:
#    cd ~/Projets/hadrienblanc/sogo/sogo/Tests/Unit
#    source ~/Projets/hadrienblanc/sogo/local/env.sh
#    NSZombieEnabled=YES ./obj/sogo-tests   # → rc=1, 7 zombie messages
#    Fix: force a full rebuild there, e.g. touch SoObjects/SOGo/*.m or
#    make clean in SoObjects/SOGo before the next run-worktree-tests.sh.

# 1. build + full unit suite on THIS branch — expect 248 tests, OK, rc=0
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
  /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-99996

# 2. zero over-releases (zombie mode), expect "0"
source /home/hadrienblanc/Projets/hadrienblanc/sogo/local/env.sh
export LD_LIBRARY_PATH="/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-99996/SOPE/NGCards/obj:/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-99996/SOPE/GDLContentStore/obj:/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-99996/SoObjects/SOGo/SOGo.framework/Versions/Current/sogo:$LD_LIBRARY_PATH"
cd /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-99996/Tests/Unit
NSZombieEnabled=YES ./obj/sogo-tests 2>&1 | grep -o "message sent to deallocated instance" | wc -l

# 3. new test is registered and runs
./obj/sogo-tests -f junit 2>/dev/null | grep -c 'test_scriptErrorOwnershipAcrossAllErrorBranches'
#   → 1
```

No e2e stack interaction was needed (pure in-process memory behavior); the
shared stack was not touched.

## PR body draft

Ticket 99996 reported that after PR #59 the sogo-tests binary still logged 7
`-[GSCInlineString release]: message sent to deallocated instance` at the
final autorelease-pool drain (and segfaulted at exit without zombies).
Investigation shows the current source is clean: a from-scratch build runs
248 tests with exit code 0 and zero over-releases under `NSZombieEnabled`.
Dumping the 7 zombie objects under gdb (breakpoint on `GSLogZombie`) shows
they are all SOGoSieveManager `scriptError` strings from the branches
exercised by the PR-#59 tests — i.e. the pre-#59 bug. The binary that
produced the report had been relinked (10:47) against a `libSOGo.so` built
from 08:08 objects, 30 minutes *before* the PR #59 fix merged (10:40), so the
new tests ran against the old framework code. Restoring the pre-#59
SOGoSieveManager.m in a scratch rebuild reproduces the exact symptom
(rc=139 segfault; 13 zombie messages of which 7 at the final drain), and
rebuilding the same commit from scratch makes it disappear.

AVANT: the scriptError ownership regression (or a stale libSOGo) is invisible
during the suite — the over-releases only trip at process exit, so a normal
`OK` run can still end in a segfault with no failing test.

APRES: `test_scriptErrorOwnershipAcrossAllErrorBranches` runs all six direct
extractor error branches inside a dedicated autorelease pool with retained
managers, releasing each manager before the pool drains — any unbalanced
`scriptError` ownership now trips inside the suite (verified against the
pre-#59 code), and the fix itself stays locked by the existing 13 branch
tests. No production code changed; the main checkout just needs a clean
rebuild of `SoObjects/SOGo` to pick up the merged fix.
