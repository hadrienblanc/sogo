# Cycle 12 clean pass — refactor/cycle-12 (base 784021d6b)

Light, high-signal pass over `fork/experimental~11..fork/experimental`
(PR merges #21–#31 in tree terms: bugs 6189, 6161, 6162, 6171, 6179,
6180, 6182, 6183, 6186 + the cycle-11 clean pass). Reviewed every
non-docs hunk of the range: production code (iCalEvent+SOGo,
SOGoContactSourceFolder, LDAPSource, SOGoGCSFolder, SOGoToolManageACL,
SOGoMailForward, NSData+Mail, NSString+Utilities, UIxPageFrame,
UIxMailListActions/UIxMailFolderActions, the UIxHTMLMailContentHandler
extraction, Scheduler/Preferences JS), the new unit tests and the new
jasmine specs.

Verdict: the cycle diff is clean. The four Mantis fixes are minimal and
idiomatic, the handler extraction is a faithful verbatim move (memory
management and the `showWhoWeAre`/statics all travelled together), and
the new tests follow the suite's established conventions
(`loadSOGoBundle:markerClass:` wrappers, per-file
`LoadAppointmentsBundle`, distinct e2e fixtures per spec). Only two
diff-introduced items were worth changing — both test hygiene, both
pure deletions. No production change justified a diff.

## Changes

### 1. `Tests/Unit/TestiCalEntityObjectAttributes.m` — dead local

`test_organizerIsExposedSeparatelyFromAttendees` declared
`iCalEvent *event;` but never used it — the method calls
`[[self _invitedEvent] attributesInContext: nil]` directly. Unused
local under `-Wall`; no behavior change.

```objc
- (void) test_organizerIsExposedSeparatelyFromAttendees
{
-  iCalEvent *event;
   NSDictionary *data, *organizer;
```

### 2. `Tests/Unit/TestNSString+CKEditorUserAgentOverride.m` — duplicated fixture

The second sub-case of `test_firefoxDesktopIsLeftAlone` was
byte-identical (UA string + assertion) to the whole of
`test_firefoxAndroidDesktopViewIsLeftAlone` — the Firefox-Android
"request desktop site" UA has exactly the desktop shape, which is the
point of the dedicated test. Dropped the redundant sub-case; the named
scenario test keeps documenting the behavior.

```objc
   ua = @"Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/20100101 Firefox/149.0";
   failIf([ua ckEditorUserAgentOverride] != nil);
-
-  ua = @"Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/149.0 Firefox/149.0";
-  failIf([ua ckEditorUserAgentOverride] != nil);
 }
```

## Reviewed and deliberately left alone

- `NSData+Mail.m` `<o:p>` stripping loop: per-removal
  `replaceBytesInRange` is O(n) worst case, but Word mails carry a
  bounded number of paragraph marks and the loop mirrors the idiom of
  the two surrounding pre-existing passes; bounds and the
  refetch-after-mutation pattern are correct.
- `ckEditorUserAgentOverride` running twice per page frame (once via
  `hasCKEditorUserAgentOverride`, once via the `<var:string>`): one
  cached-regex scan each on a once-per-page render; not worth caching.
- The magic `6` (= length of `@"Gecko/"`) in `ckEditorUserAgentOverride`:
  pinned by `TestNSString+CKEditorUserAgentOverride.m`; consistent with
  the raw-offset style used throughout `NSString+Utilities.m` and
  `NSData+Mail.m`.
- The Contacts→Mailer bundle load order in `TestNSData+Mail.m` /
  `TestSOGoMailForward.m` / `TestSOGoDraftObject.m`: pre-existing
  convention explicitly kept by the cycle-11 pass; `Mailer.SOGo` links
  no Contacts object but the order is harmless and consistent.
- `UIxHTMLMailContentHandler.m` legacy tab/space mixing and the
  `isBase64` attribute re-scan inside the `src` branch: verbatim from
  the move out of `UIxMailPartHTMLViewer.m` (pre-existing logic);
  reformatting or restructuring a 750-line move would drown the diff in
  noise.
- The `LoadAppointmentsBundle()` / `_eventWithContent:` per-file
  helpers repeated across the four iCal test files: the suite's
  established convention; factoring them into `SOGoTest` would couple
  the shared runner to NGCards.
- `SOGoGCSFolder.m` uncommented DAV `read` registration: the surviving
  indentation (tab-continuation) matches the sibling registrations in
  the same block.
- `LDAPSource.m` `membersForGroupWithUID` call structure: the
  `members` local exists precisely to avoid a second LDAP round-trip
  when the cache misses twice — correct as is.
- Pre-existing `margin-left/right` regex duplication in
  `UIxMailPartHTMLViewer.m` (two 8-line blocks): untouched by this
  cycle's diff, out of scope per the rules.

## Verification

- Worktree bootstrapped with `./configure --enable-debug
  --disable-strip` (gitignored `config.make`, same flags as the other
  worktrees).
- Unit suite (`local/run-worktree-tests.sh` on this worktree):
  **147 tests, 2 failures, 0 errors** — exactly the two known host-noise
  failures (`test_NGInternetSocketAddressFromString` dual-stack
  localhost, `test_stringWithoutHTMLInjection` GNUstep-base regex
  quirk). Identical failure set to the pre-change baseline; +21 tests
  vs cycle 11's 126.
- Both edits are deletions in test code; no production path touched,
  no compile flags changed.

One commit on `refactor/cycle-12`; not pushed, no PR opened.
