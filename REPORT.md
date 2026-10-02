# Cycle-16 clean-code pass

Scope: the orchestrator range `fork/experimental~11..fork/experimental`,
reviewed in this worktree (`refactor/cycle-16`).

Range note: `~11` follows first parents and resolves to `56b3a499b` (PR #40's
merge), so the tree-diff re-sweeps PRs #41–#51 (+2237/−187 over 33 files).
PRs #41–#46 were already covered by the cycle-14 and cycle-15 passes (see
their REPORT.md commits `5f07a947c` and `5bf5a1644`); they were re-sanity-
checked here, but the new, never-reviewed material is the cycle's own content
`bbfeebb3b..8b1c52675` — PRs #48–#51:

- PR #48 `cb8ac4a2b` — test(mail): inline SVG images never rendered (bug 6152)
- PR #49 `fa0aaf072` — test(defaults): SOGoRefreshViewCheck string contract (bug 6142)
- PR #50 `7f1ddb298` — fix(calendar): honor last VTIMEZONE transition (bug 6133)
- PR #51 `712e6c322` — test(user-profile): legacy plist-to-JSON conversion (bug 6129)

## What I changed

### 1. Misindented continuation in the SVG extraction test (PR #48)

`Tests/Unit/TestNSString+Mail.m` — the new
`test_htmlByExtractingImagesExtractsSVGDataURLOfTicket6152` split its receiver
over four lines, but the selector line was indented two spaces past the
statement's own string continuations:

```objc
  // before
  result = [@"<p>Test signature</p>"
            @"<p><img src=\"data:image/svg+xml;base64,…\""
            @" width=\"391\" height=\"232\"></p>"
              htmlByExtractingImages: images];        // ← 14 spaces

  // after
  result = [@"<p>Test signature</p>"
            @"<p><img src=\"data:image/svg+xml;base64,…\""
            @" width=\"391\" height=\"232\"></p>"
            htmlByExtractingImages: images];          // ← 12 spaces
```

Whitespace-only; the selector now aligns under the `@"` of the literal it is
sent to, like the rest of the file. (This is different from the one-space
colon-alignment noise rejected in cycle-15: here the lines of a single
statement disagreed with each other.)

That is the only code change. Everything else reviewed came out clean or was
deliberately left alone — an empty-commit-for-the-sake-of-committing would
have been worse than this one small fix.

## What was reviewed and deliberately left alone

### PR #50 — VTIMEZONE last transition (bug 6133, `7f1ddb298`)

- `occurrenceForDate:` (`SOPE/NGCards/iCalTimeZonePeriod.m:301`): the fix
  replaces a third condition with `else`, which both removes the bug
  (beyond-UNTIL dates left `tmpDate` nil, hiding the final STANDARD period)
  and deletes a redundant `_occurrenceForDate:byRRule:` computation on that
  path. Minimal and correct as landed.
- `TestiCalTimeZoneFallback.m`: the three fixtures (Mozilla-style,
  Evolution-style, Berlin recurring) are each defined once and shared across
  tests; no duplicated fixtures. The non-ASCII-free expectations
  (`timeIntervalSince1970` equality) are exact and deterministic.

### PR #48 — inline SVG non-rendering (bug 6152, `cb8ac4a2b`)

- `TestNGMimeBodyPart+SOGo.m`: imports `<SOGo/NGMimeBodyPart+SOGo.h>`,
  consistent with the other `<SOGo/…>` category imports (the header lives in
  `SoObjects/SOGo/`).
- `TestUIxMailRenderingContext.m`: `tearDown` omits `[super tearDown]`, but
  the base `SOGoTest tearDown` is a no-op and 4 of the 6 test files that
  override it do the same — majority local convention, not worth churning.
- `MailSvgInlineImageSpec.js` duplicates `_putMessage`/`_fetchView` from
  `MailerRemoteImagesSpec.js` (PR #44, same range) — but the per-spec-file
  helper pattern predates the cycle (`MailDAVSpec.js`, `MailHtmlRenderingSpec.js`,
  `MailerCyrillicLabelsSpec.js` each carry their own). Refactoring all five
  into `Tests/lib/` is a repo-wide change, not a cycle-diff cleanup; noted as
  a candidate for a future cycle.

### PR #49 — SOGoRefreshViewCheck contract (bug 6142, `fa0aaf072`)

- `TestSOGoUserDefaults.m`: the `_defaultsWithSource:parentSource:` factory
  keeps each test to a single assertion concern; the before/after restore
  pattern in `HTTPRefreshViewCheckSpec.js` mirrors `HTTPPreferencesSpec.js`.
  No fixture duplication.

### PR #51 — plist-to-JSON profile conversion (bug 6129, `712e6c322`)

- `TestSOGoUserProfile.m` exercises the private `_convertPListToJSON:` via a
  category declaration — same technique as other tests reaching class
  internals. Fixtures are distinct (final-semicolon variant, unparsable
  variant). Clean.

### GNUmakefile (all four PRs touch it)

- `-I../../` addition: required — `UI/MailPartViewers/UIxMailRenderingContext.m`
  imports `<SoObjects/Mailer/…>`, a 83-occurrence idiom in `UI/` that only
  resolves from the repo root. Correct minimal enabler, not include-path
  sprawl.
- `TestNSArray+Utilities.m` is listed mid-`NSString` group; pure list-order
  churn, left alone.

### Re-sanity-check of the older range content (PRs #41–#46)

- `SOGoDraftObject bodyPartForAttachmentWithName:` — retain discipline
  verified: mapped-file `NSData` autoreleased before the base64 reassignment,
  `NGMimeFileData` body released after `setBody:` (`SOGoDraftObject.m:1586`).
- `SOGoMailFolder postData:flags:` — the "already exists" tolerance keeps the
  502 path for genuine CREATE failures; matches the file's error style.
- `UIxPreferences saveAction` categories-colors loop — the `int count` +
  double `objectAtIndex:` pattern exactly mirrors the pre-existing
  mail-labels block directly below it (`UIxPreferences.m:1860`); changing
  only the new block would create inconsistency, changing both exceeds a
  light pass.
- `UIxMailView _senderIsInAddressBook` — re-verified it must NOT reuse
  `contactForEmail:` (substring-match would reintroduce the spoof vector;
  cycle-15 reached the same conclusion).
- `UIxMailEditor _scanAttachmentFilenamesInRequest:` — `declaredMimeType` is
  not reset after consumption, but uploads carry exactly one file part per
  request (see `angular-file-upload.trump.js`), so no cross-attachment leak
  is possible; resetting it would be dead code.

## Follow-up found, out of scope for this pass

- `UI/WebServerResources/js/Mailer.services.js` was hand-patched in
  `79f7fdb13` to mirror the `senderInAddressBook` policy, but its tracked
  sourcemap `Mailer.services.js.map` was **not** regenerated (last touched by
  `3b397622e`; the new symbol is absent from its `names`). Same for
  `vendor/angular-file-upload.min.js` vs its `.map`. Regenerating requires
  the project's grunt/uglify pipeline (`UI/WebServerResources/Gruntfile.js`,
  no `node_modules` on this host) and would rewrite the whole minified line —
  too blunt for a clean pass. Recommend a `chore(js): regenerate sourcemaps`
  commit from a machine with the toolchain.

## Tests

`local/run-worktree-tests.sh wt/c16-clean` — full unit suite green except the
two documented host-noise failures (`test_NGInternetSocketAddressFromString`,
`test_stringWithoutHTMLInjection`): **Ran 221 tests, FAILED (2 failures,
0 errors)** — no worse than baseline.

Host note: after printing that summary, the `sogo-tests` binary segfaults
during GNUstep-base exit teardown (libobjc `class_getMethodImplementation`
reached from `main` return, `sogo-tests.m:128`). This is pre-existing
environment behavior — the same post-summary SIGSEGV appears in coredumps of
the cycle-15 worktrees and the main checkout (`08:05`, `08:08`, before any
cycle-16 merge), so it is not attributable to this cycle's diff.
