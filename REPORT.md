# Cycle-15 clean-code pass

Scope: the cycle-15 diff, reviewed in this worktree (`refactor/cycle-15`).

Range note: the orchestrator range `fork/experimental~11..fork/experimental`
resolves to `e25690d44` (PR #35's merge) because `~11` follows first parents
and each PR is one merge hop. That tree-diff would re-sweep PRs #36–#41, which
the cycle-14 pass already covered (see its REPORT.md). The actual cycle-15
content — the 11 commits of PRs #42–#46 listed by the orchestrator — is
`3ab37dc92..c126ff5b0` (18 files, +1104/−97), and that is what this pass
reviewed. The two commits inside PR #42 are the cycle-14 pass's own output and
were only sanity-checked.

## Verdict: no code changes — zero commits over the diff

After a method-by-method review against each file's prevailing style, I found
no defect worth a commit. An empty-commit-for-the-sake-of-committing would be
worse than none. Everything verified is documented below, including the
candidates I deliberately rejected.

## What was reviewed and deliberately left alone

### PR #43 — unparsable JSON save payload (bug 6211, `abc1a32db`)

- `saveAction` (`UI/PreferencesUI/UIxPreferences.m:1756`): the new 400 return
  matches the file's existing `responseWithStatus:andJSONRepresentation:`
  error paths (TOTP/factor validation below use the same shape). The
  continuation indent is one space off strict colon alignment, but the file's
  own call sites (lines 1974, 2016) are inconsistent among themselves — a
  one-space diff would be noise, not consistency.
- `TestNSString+Utilities.m` additions follow the file's `testEquals` /
  `testWithMessage` conventions and lock the exact ticket payload.

### PR #44 — remote images from known senders (bug 6170, `79f7fdb13` + `906d3030c`)

- `_senderIsInAddressBook` (`UI/MailerUI/UIxMailView.m:275`): this is NOT a
  reimplementation of the existing `-[SOGoContactFolders contactForEmail:]`
  (`SoObjects/Contacts/SOGoContactFolders.m:506`). That method takes
  `lastObject` of the fuzzy `allContactsFromFilter:` result with no exact
  verification — precisely the substring-spoof vector the commit message says
  it defends against. The explicit exact-match loop is the security decision;
  factoring it onto `contactForEmail:` would reintroduce the bug.
- Loop idiom (`for (count = 0; !known && count < max; count++)`) mirrors the
  sibling early-exit loops in the same file (lines 458 and 508). The lookup is
  gated on the `known` preference, so other configurations pay nothing.
- `Message.service.js`: `Message.$displayRemoteInlineImages` now carries the
  raw preference string instead of a boolean — verified the minified
  `Mailer.services.js` was regenerated to mirror it exactly (old `=!0` branch
  replaced by the junk-folder/known-sender policy).
- `MailerRemoteImagesPolicySpec.js` reuses the stub-Message-service pattern
  already established by `MailerMessageFlagsSpec.js` /
  `MailerIdentitySignatureSpec.js`. Each spec carries its own lodash/angular
  stubs; the duplication predates this diff, so factoring a shared helper is
  out of scope for this pass (candidate for a future cycle).
- `906d3030c` (missing semicolons after `ASSIGNCOPY`): correct as landed,
  nothing further.

### PR #45 — sanitize categories after JSON decoding (bug 6158, `d550d93ec`)

- `stringsWithoutHTMLInjection:stripAngular:` (`NSArray+Utilities.m:175`)
  uses the same `objectEnumerator` walk as `flattenedArray`/`uniqueObjects`
  in the same file; capacity hint on the mutable array; correct
  autorelease discipline.
- The `SOGoCalendarCategoriesColors` key-sanitization loop
  (`UIxPreferences.m:1793`) repeats `[categoryNames objectAtIndex: count]`
  twice per iteration and structurally echoes the pre-existing mail-labels
  loop 60 lines below (line 1860). Both are the file's local idiom; rewriting
  only the new copy would diverge from its sibling, and the dictionaries are
  tiny (category colors), so there is no performance to reclaim. Left as is.
- `[v setObject: sanitizedCategoriesColors  forKey: ...]` double space matches
  the surrounding `setObject:...  forKey:` calls (lines 1806, 1873, 1880).
- `TestNSArray+Utilities.m`: it imports `Foundation/NSValue.h` and
  `Foundation/NSDictionary.h` without referencing either class directly —
  harmless over-importing that GNUstep test files in this tree commonly
  carry; trimming it is below the signal threshold for a commit.

### PR #46 — append to Sent when CREATE reports "already exists" (bug 6153, `f293a2758`)

- `postData:flags:` (`SoObjects/Mailer/SOGoMailFolder.m:1046`): declare-then-
  `error = nil;` matches the file's existing idiom (line 859–863). The
  case-insensitive "already exists" probe handles a nil `reason` safely
  (message-to-nil returns an empty range). Error paths (502 otherwise,
  append error propagated) are all covered by `TestSOGoMailFolder.m`.
- `TestSOGoMailFolder.m`: the `objc_allocateClassPair` stub is self-contained,
  its statics have correct retain/release discipline (retained for captured
  arguments, plain assignment for scenario configuration reset in `setUp`),
  and it duplicates no fixture from other test files.

## Test hygiene

- `Tests/Unit/GNUmakefile`: `TestNSArray+Utilities.m` and
  `TestSOGoMailFolder.m` each appear exactly once; no duplicated link flags or
  merge debris from the five-way PR merge.
- No duplicated fixtures between `MailerRemoteImagesSpec.js`,
  `MailerRemoteImagesPolicySpec.js` and `HTTPPreferencesSpec.js` — each owns
  distinct messages/cards/mailboxes with unique `test-6170-*` identifiers.

## Unit suite (baseline = after review, no changes)

`local/run-worktree-tests.sh wt/c15-clean` — **Ran 202 tests, 2 failures,
0 errors**, exactly the two known host-noise failures:

- `test_NGInternetSocketAddressFromString` (dual-stack localhost)
- `test_stringWithoutHTMLInjection` (GNUstep-base empty-template regex quirk)

Note: the test binary segfaults during process teardown *after* the summary
is printed (exit 139, inside `libgnustep-base` class cleanup — coredump
backtrace shows `class_getMethodImplementation` from gnustep-base at exit).
This predates this pass: identical coredumps exist from the `wt/c15-6153`
worktree at 07:56, before this agent started. It is host/runtime noise, not a
regression from the cycle diff. No code was changed, so the suite state is by
definition unchanged from the cycle's merged state.
