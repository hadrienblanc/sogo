# Cycle 11 clean pass — refactor/cycle-11 (base c1a9d3403)

Light, high-signal pass over `fork/experimental~11..fork/experimental`
(PRs #16–#26: bugs 6214, 6193, 6192, 6191, 6189, 6186, 6183, 6182, 6180 +
refactors). The cycle diff is largely in good shape: the
`UIxHTMLMailContentHandler` extraction is a faithful move (plus testable
accessors), the `attachUrlsForEditor`/`setAttachUrlsFromEditor` factoring
removed real duplication from `UIxComponentEditor`, and the new tests are
well-targeted. Five items were worth fixing — all diff-introduced, all
minimal.

## Changes

### 1. `UIxMailFolderActions.m` — redundant dictionary lookup in the factored error response

`_storeFlagsErrorResponse:` (introduced by 2ccc518f9 to deduplicate
`addOrRemoveLabelAction`/`removeAllLabelsAction`) fetched
`[result objectForKey: @"reason"]` twice — once for the log line, once for
the JSON body.

```objc
  [self errorWithFormat: @"%@: unable to store flags %@: %@",
                     action, flags, [result objectForKey: @"reason"]];
  o = [result objectForKey: @"reason"];
```

→ single lookup, message unchanged:

```objc
  o = [result objectForKey: @"reason"];
  [self errorWithFormat: @"%@: unable to store flags %@: %@",
                     action, flags, o];
```

### 2. `TestNSData+Mail.m` — unneeded bundle load in `setUp`

The test exercises `-[NSData sanitizedContentUsingVoidTags:]`, a category
compiled into `Mailer.SOGo` (see `SoObjects/Mailer/GNUmakefile:41`); its
setUp loaded `Appointments.SOGo` with the `SOGoDraftObject` marker — a
bundle that can never provide that marker and has no link relationship
with Mailer. Dropped the line; kept the pre-existing Contacts→Mailer
pattern used by `TestSOGoDraftObject`/`TestSOGoMailForward`.

### 3. iCal test files — doubled `LoadAppointmentsBundle()` guard (14 sites)

The three new test files guarded every method with the loader called
twice back-to-back:

```objc
  testWithMessage (LoadAppointmentsBundle (),
                   @"Appointments.SOGo bundle unavailable");
  if (!LoadAppointmentsBundle ())
    return;
```

→ single call, same failure reporting (one `testWithMessage` failure then
skip), matching the house `testWithMessage (NO, …)` style already used in
`TestRTFHandler.m`:

```objc
  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }
```

Files: `TestiCalEntityObjectAttachUrls.m` (8×), `TestiCalEntityObjectAttributes.m` (3×),
`TestiCalRepeatableEntityObject+SOGo.m` (3×).

### 4. `TestUIxHTMLMailContentHandler.m` — undeclared helper

`feedBodyElement:attributes:rawTag:` was the only feed helper of the
class not declared in its `@interface` (`feedStyle:`,
`feedBodyCharacters:` were). Declared it for consistency (and to keep
call sites warning-free under stricter compilers).

### 5. `Tests/spec/HTTPPageFrameCKEditorSpec.js` — duplicated auth fixture

The spec re-implemented `getAuthCookie()` (16 lines of `/SOGo/connect`
parsing) although `Tests/lib/Preferences.js` already provides
`getAuthCookie()` — the helper used by every other authenticated spec,
including the sibling `MailHtmlRenderingSpec.js` from this same cycle.
Rewritten to `new Preferences(config.username, config.password)` +
`await preferences.getAuthCookie()`; assertions untouched.

Verified live against the e2e stack (127.0.0.1:50001): the cookie
produced by the shared helper yields HTTP 200 on
`/SOGo/so/sogo-tests1/Mail/view` with the Firefox-Android UA, with both
`Object.defineProperty(navigator, 'userAgent'` and the desktop
`Gecko/149 Firefox/149` override present in the page — same result as the
previous inline implementation. (Note: the in-container jasmine runner is
currently broken at module-load for *all* specs, pristine tree included —
`utils.js`'s `String.startsWith` polyfill hooks Node's module resolver.
Pre-existing container state, not caused by this change.)

## Reviewed and deliberately left alone

- `NSData+Mail.m` `<o:p>` stripping loop: per-removal
  `replaceBytesInRange` is O(n) worst case, but Word mails carry a bounded
  number of paragraph marks and the loop mirrors the idiom of the
  surrounding passes; not worth restructuring.
- `UIxHTMLMailContentHandler.m` tab/space mixing and the legacy
  `- (void)activateRawContent` spacing: verbatim from the move out of
  `UIxMailPartHTMLViewer.m`; reformatting a 750-line move would drown the
  cycle diff in noise.
- `UIxMailEditor.m setBase64ImagesInText:` 8-space indentation and the
  dead `&& contentId` re-test: pre-existing in that method, the cycle only
  re-wrapped two lines.
- `ckEditorUserAgentOverride`'s magic `6` (= length of `@"Gecko/"`):
  behavior is pinned by tests; a named constant adds little.
- The three per-file `LoadAppointmentsBundle()`/`_eventWithContent:`
  helpers triplicated across the new iCal test files: factoring them into
  `SOGoTest` would couple the shared runner to NGCards; per-file static
  helpers are the suite's existing convention.
- The mini Angular stubs in the three new pure-JS spec files
  (`MailerIdentitySignatureSpec`, `PreferencesIsDateCompleteSpec`,
  `SchedulerComponentControllerSpec`): each stubs a different dependency
  set; a shared loader would be speculative.

## Verification

- Unit suite (`local/run-worktree-tests.sh` on this worktree):
  **126 tests, 2 failures, 0 errors** — exactly the two known host-noise
  failures (`test_NGInternetSocketAddressFromString` dual-stack localhost,
  `test_stringWithoutHTMLInjection` GNUstep-base regex quirk). Identical
  to the pre-change baseline.
- `UIxMailFolderActions.m` is not part of the unit tool; syntax-checked
  standalone with the test tool's exact compile flags (clean; the two
  `-folderWithTraversal:` warnings in that file pre-date this cycle).
- CKEditor spec behavior re-verified live as described above.

One commit on `refactor/cycle-11`; not pushed, no PR opened.
