# Ticket 99997 — sogo-tests segfaults at exit: over-released GSCInlineString

Branch: `fix-99997-mantis` — commit `334378a53`

## Root cause (file:line)

`SoObjects/SOGo/SOGoSieveManager.m` — the `scriptError` instance variable was
assigned **non-owned** strings at every error site (autoreleased
`[NSString stringWithFormat: ...]` results at former lines 348, 388, 538, 566,
630, 636 and constant literals at 334, 353, 393, 429, 571, 581), while the
object unconditionally released it in `dealloc` (line 267) and at the start of
each script generation (`sieveScriptWithRequirements:delimiter:`, lines
663-664). The `[scriptError retain]` at former line 683 only compensated when a
full script generation completed; any other path (direct rule/action
extraction, as done by `TestSOGoSieveManager`) left the ivar owning nothing.

Sequence proven under gdb with `NSZombieEnabled=YES`:

1. `_extractSieveAction:` sets `scriptError = [NSString stringWithFormat:
   @"Action with invalid flag argument '%@'", argument]` — autoreleased,
   count 1, the pool owes one release.
2. The autoreleased `SOGoSieveManager` and the string sit in the same pool
   (manager autoreleased first).
3. At pool drain (`[pool release]` at the end of `main`, sogo-tests.m:128),
   the manager is released first → `dealloc` → `[scriptError release]` →
   count 1→0 → the string is freed.
4. The pool then releases the string again → use-after-free → SIGSEGV in
   `class_getMethodImplementation` (libobjc) via the NSAutoreleasePool drain.
   gnustep-base 1.31 represents the small single-byte string as a
   `GSCInlineString`, hence "over-released GSCInlineString" in the ticket.

The crash also reproduced on a clean `experimental` checkout (coredump of
10:23:39), so this is a genuine regression in the tree, not host noise.

## What changed (before/after)

`SoObjects/SOGo/SOGoSieveManager.m`:

- **Before**: `scriptError = <literal or autoreleased string>;` at 12 sites —
  ivar holds a borrowed reference.
- **After**: `ASSIGN(scriptError, ...);` at every value-assignment site (the
  macro retains the new value before releasing the old one), using the
  parenthesized-expression form `ASSIGN(scriptError, ([NSString
  stringWithFormat: ...]))` where the expression contains commas, matching the
  existing `SOGoMailFolder.m:380` idiom.
- **Before**: `[scriptError retain];` at the end of
  `sieveScriptWithRequirements:delimiter:` (a broken compensation that only
  worked when a full generation ran to completion).
- **After**: removed — the ivar now always owns its value; `[scriptError
  release]; scriptError = nil;` at the start of the method and `[scriptError
  release]` in `dealloc` are now correctly balanced.
- `scriptError = nil;` in `init` (nothing to release yet) and the borrowed
  `lastScriptError` getter are unchanged.

AVANT (crash):

```
$ ./obj/sogo-tests
...
Ran 234 tests

OK
Segmentation fault (core dumped)      # exit 139, coredumpctl shows the
                                      # crash in the [pool release] of main
```

APRES (fix):

```
$ ./obj/sogo-tests
...
Ran 247 tests

OK
$ echo $?
0                                      # clean exit, no coredump
```

## Tests

`Tests/Unit/TestSOGoSieveManager.m` extended (file already registered in
`Tests/Unit/GNUmakefile`), 13 new test methods covering every `scriptError`
assignment branch touched by the fix:

- `test_extractSieveAction_unknownMethod`, `..._missingArgument`,
  `..._missingMethod` — action error branches (former lines 566, 571, 581).
- `test_extractSieveRule_validRule` — happy path (regression guard).
- `test_extractSieveRule_withoutField`, `..._unknownField`,
  `..._headerWithoutCustomHeader`, `..._withoutOperator`,
  `..._unknownOperator`, `..._withoutValue` — rule error branches
  (former lines 353, 348, 334, 393, 388, 429).
- `test_convertScriptToSieve_badTest`, `..._matchWithoutRule` — script
  conversion error branches (former lines 636, 630).
- `test_sieveScriptWithRequirements_resetsPreviousError` — sets an error
  (owned via ASSIGN), runs a full generation and verifies the error is
  released/reset without side effects (covers the removed-retain path).

## Verification steps for the orchestrator

```bash
# 1. build + full unit suite, expect clean exit (was: SIGSEGV after "OK")
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
  /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c34-99997
#   → "Ran 247 tests" / "OK" / exit code 0

# 2. confirm no over-release remains (zombie mode, expect no report)
source /home/hadrienblanc/Projets/hadrienblanc/sogo/local/env.sh
export LD_LIBRARY_PATH="/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c34-99997/SOPE/NGCards/obj:/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c34-99997/SOPE/GDLContentStore/obj:/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c34-99997/SoObjects/SOGo/SOGo.framework/Versions/Current/sogo:$LD_LIBRARY_PATH"
cd /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c34-99997/Tests/Unit
NSZombieEnabled=YES ./obj/sogo-tests |& grep -c "message sent to deallocated"
#   → 0   (before the fix: "*** -[GSCInlineString release]: message sent to
#          deallocated instance" printed at exit)

# 3. no new coredumps
coredumpctl list --no-pager | tail -3
```

No e2e stack interaction was needed (pure in-process memory bug); the shared
stack was not touched.

## PR body draft

The `sogo-tests` unit runner segfaulted (SIGSEGV) right after printing its
final report, whenever a test exercised a SOGoSieveManager error branch.
Every error site assigned a non-owned string to the `scriptError` ivar —
either an autoreleased `+[NSString stringWithFormat:]` result or a constant
literal — while `-dealloc` and the next `sieveScriptWithRequirements:
delimiter:` call unconditionally released it. With the manager and the
autoreleased error string sitting in the same pool, the pool drain released
the manager first, whose dealloc freed the error string, and the pool's own
balancing release then hit freed memory — crashing at process exit in
`[NSAutoreleasePool drain]` (visible as an "over-released GSCInlineString",
gnustep-base's representation of small single-byte strings). The bug also
affected production code paths: any mail-filter save that hit one of these
error branches left the manager with a dangling `scriptError` ivar and
over-released the string at dealloc.

AVANT: `scriptError = [NSString stringWithFormat: @"Action with invalid flag
argument '%@'", argument];` (borrowed reference stored in the ivar) +
`[scriptError retain];` bolted on at the end of full generations only —
sogo-tests exits with `Segmentation fault (core dumped)`.

APRES: every assignment uses `ASSIGN(scriptError, ...)` (retain + release-old
+ assign, the parenthesized form where the expression contains commas,
matching `SOGoMailFolder.m`), the compensating retain is removed, and the
ivar's ownership is balanced in all paths. sogo-tests now runs 247 tests
(13 new ones covering every touched error branch plus a generation-reset
case) and exits cleanly with code 0; `NSZombieEnabled=YES` reports zero
over-releases.
