# Ticket 99995 — stringWithoutHTMLInjection throws NSInvalidArgumentException on GNUstep (javajavascript:script:)

Branch: `fix-99995-mantis`

## Root cause (file:line)

GNUstep-base's `-[NSRegularExpression stringByReplacingMatchesInString:options:range:withTemplate:]`
returns **nil whenever the replacement result would be the empty string**, where
Apple's Foundation returns `@""`. Verified empirically on this host's
gnustep-base with a standalone probe (all combinations of empty/non-empty
input × no-match/match × empty/non-empty template): nil ⇔ empty result; a
no-match on a non-empty input returns the input unchanged; a match with a
non-empty template never returns nil.

In `SoObjects/SOGo/NSString+Utilities.m`, `stringWithoutHTMLInjection:
stripAngular:` first *deletes* the `javascript:`/`vbscript:`/`livescript:`
schemes (loop-until-stable since PR #57), so an input such as the ticket's
`"javajavascript:script:"` — or any empty input `@""` — legitimately reaches
the first substitution stage with `result == @""` (pre-fix line 1160):

```objc
newResult = [regex stringByReplacingMatchesInString:result ... withTemplate:@"<scr***"];  // nil on GNUstep
result = [NSString stringWithString: newResult];                                          // raises NSInvalidArgumentException
```

`+[NSString stringWithString:]` with a nil argument raises
`NSInvalidArgumentException`. The method's own `NS_DURING`/`NS_HANDLER`
(pre-fix line 1226) catches it, logs
`Error while stripping HTML injection : NSInvalidArgumentException` and
**aborts all remaining sanitization passes**; the returned value was correct
only by coincidence (an empty string cannot be modified by the later passes).
Reproduced against the built `libSOGo` before the fix: every one of `@""`,
`@"javascript:"`, `@"javajavascript:script:"` logged the exception. The
pre-fix unit suite (248 tests, OK) still logged **3** swallowed exceptions —
the bug was invisible to value-based assertions.

Same GNUstep quirk, same file, sibling method:
`removeHTMLTagsExceptAnchorTags` (pre-fix line 1042) deletes tags with an
**empty template**, so tag-only content (`@"<hr>"`) made it return **nil**
(no exception involved — nil leaked straight to the caller,
UI/MainUI/SOGoRootPage.m:1549 renders the admin MOTD through it).

The other `stringByReplacingMatchesInString` callers
(UI/MailPartViewers/UIxMailPartHTMLViewer.m:317-322, 489-494) are guarded by
`if ([cssContent length])` and use non-empty templates, so their result can
never be empty — not affected.

## What changed (before/after)

`SoObjects/SOGo/NSString+Utilities.m` — new file-scope helper next to the
existing `RemoveRegexMatches` (NSString+Utilities.m:1030), mirroring Apple
semantics for the GNUstep nil case:

```objc
static NSString * ReplaceRegexMatches(NSString *string, NSRegularExpression *regex, NSString *template)
{
  NSString *result;

  result = [regex stringByReplacingMatchesInString: string
                                            options: 0
                                              range: NSMakeRange(0, [string length])
                                       withTemplate: template];

  return (result != nil) ? result : @"";
}
```

- `stringWithoutHTMLInjection:stripAngular:` — all 10 substitution sites
  (`<script`, `</script`, `<iframe`, `<form`, `</form`, `on...=` handlers,
  `@import`, `{{`/`}}` angular braces, final `@import` loop) now go through
  the helper; each site's `newResult = ...; result = [NSString
  stringWithString: newResult];` pair collapses to
  `result = ReplaceRegexMatches(result, regex, @"template");`. No more
  `[NSString stringWithString: nil]` → no exception, no mid-way abort, the
  whole filter chain always runs.
- `removeHTMLTagsExceptAnchorTags` (NSString+Utilities.m:1054) — deletion now
  goes through the helper: full-tag content returns `@""` instead of nil.

No behavior change on Apple platforms (their implementation never returns
nil). No retain/release changes needed: everything stays autoreleased, as in
the rest of the method.

## Tests

`Tests/Unit/TestNSString+Utilities.m` (file already registered in
`Tests/Unit/GNUmakefile`):

- **new** `test_stringWithoutHTMLInjectionWhenFullySanitized` — the ticket's
  family of inputs whose sanitization legitimately ends in `@""`: empty
  string (both `stripAngular` modes), `javascript:`, `JAVASCRIPT:`,
  `vbscript:`, `livescript:`, separator-obfuscated `j a v a s c r i p t:`,
  and `javascript:{{1337*1337}}` (scheme deleted → `@""`-adjacent path, then
  angular escaping still applied). Locks the "fully sanitized → exactly @"",
  never nil, never partial" contract.
- `test_stringRemoveHTMLTagsExceptAnchorTags` (existing) — extended with
  tag-only inputs `<hr>` and `<div><span></span></div>` → `@""`. This one is
  red before / green after the fix (pre-fix returned nil →
  `objects '(null)' and '' differs`).

Red→green proven on this worktree by stashing only
`SoObjects/SOGo/NSString+Utilities.m` and rebuilding: pre-fix run fails 1
test (`test_stringRemoveHTMLTagsExceptAnchorTags`) and logs **24**
`Error while stripping HTML injection : NSInvalidArgumentException` (23 from
the new empty-sanitization assertions + the pre-existing ones); post-fix run
is 249 tests, OK, **0** exception logs.

Note for the orchestrator: the AGENTS.md "known host-noise failure
`test_stringWithoutHTMLInjection`" note is stale on a fresh build — this
worktree (base experimental @ 3794126cd, before this fix) already passes it;
the old failure was the stale main-checkout libSOGo (see ticket 99996's
report). The note can be dropped from AGENTS.md whenever convenient.

## Verification steps for the orchestrator

```bash
# 1. build + full unit suite on THIS branch — expect 249 tests, OK, rc=0
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
  /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-99995 2>&1 | tee /tmp/99995.log | tail -4
#    → "Ran 249 tests" / "OK"

# 2. the ticket's NSInvalidArgumentException is gone — expect 0
grep -c "Error while stripping HTML injection" /tmp/99995.log

# 3. new tests are registered and pass
source /home/hadrienblanc/Projets/hadrienblanc/sogo/local/env.sh
cd /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-99995/Tests/Unit
export LD_LIBRARY_PATH="/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-99995/SOPE/NGCards/obj:/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-99995/SOPE/GDLContentStore/obj:/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-99995/SoObjects/SOGo/SOGo.framework/Versions/Current/sogo:$LD_LIBRARY_PATH"
./obj/sogo-tests -f junit 2>/dev/null | grep -c 'test_stringWithoutHTMLInjectionWhenFullySanitized'   # → 1
./obj/sogo-tests -f junit 2>/dev/null | grep -c 'test_stringRemoveHTMLTagsExceptAnchorTags'           # → 1

# 4. (optional red proof) revert only the production file and rerun step 1:
#    git -C /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-99995 stash push -- SoObjects/SOGo/NSString+Utilities.m
#    → FAILED (1 failures): test_stringRemoveHTMLTagsExceptAnchorTags "(null)" vs ""
#    → grep -c "Error while stripping HTML injection" = 24 ; then: git stash pop && rerun step 1
```

No e2e stack interaction was needed (pure in-process sanitization behavior);
the shared stack was not touched and no `test-99995-*` artifacts were created.

## PR body draft

Ticket 99995 reports `stringWithoutHTMLInjection` throwing
`NSInvalidArgumentException` on GNUstep for inputs like
`javajavascript:script:`. Root cause: GNUstep-base's
`stringByReplacingMatchesInString:...withTemplate:` returns nil whenever the
replacement result would be the empty string (Apple returns `@""`), and the
method then called `[NSString stringWithString:]` on that nil — raising the
exception. The method's internal `NS_HANDLER` swallowed it (logging
`Error while stripping HTML injection`), so values looked right only because
an empty string cannot be altered by the later passes; every empty input
sanitized on GNUstep — e.g. every empty subject/name field — aborted the
filter chain mid-way and logged the error. The same GNUstep quirk made
`removeHTMLTagsExceptAnchorTags` return nil for tag-only content such as a
`<hr>`-only MOTD. The fix routes every regex substitution (and the tag
deletion) through a small `ReplaceRegexMatches` helper that maps GNUstep's
nil back to `@""`, matching Apple semantics; no change on macOS builds.

AVANT (GNUstep): `[[NSString stringWithString:@"javajavascript:script:"]
stringWithoutHTMLInjection:NO stripAngular:NO]` → logs
`Error while stripping HTML injection : NSInvalidArgumentException`,
remaining passes skipped (returned `@""` by luck); `[@"" ...]` same; and
`[[NSString stringWithString:@"<hr>"] removeHTMLTagsExceptAnchorTags]` →
`(null)`.
APRES: both return exactly `@""`, silently, with the full filter chain
executed; the suite's swallowed-exception log count drops from 3 (24 with the
new tests) to 0, and `test_stringRemoveHTMLTagsExceptAnchorTags` goes red →
green on the tag-only cases, locking the fix.
