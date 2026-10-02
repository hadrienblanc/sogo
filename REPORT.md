# Cycle-14 clean-code pass

Scope: `fork/experimental~11..fork/experimental` (PRs #31–#41), reviewed in this
worktree (`refactor/cycle-14`). Light pass over style/consistency, dead code,
duplicated logic introduced by the diff, performance smells in new code, and
test hygiene.

## What I changed (2 commits)

### 1. `perf(mailer): detect full HTML documents without lowercasing the whole body`
`SoObjects/Mailer/NSString+Mail.m` — `isFullHTMLDocument` (introduced by the
bug 6135 fix) built a full lowercased copy of the message body on every HTML
draft save, only to run two substring searches:

```objc
/* before */
lowercased = [self lowercaseString];
r = [lowercased rangeOfString: @"<!doctype"];
if (r.length == 0)
  r = [lowercased rangeOfString: @"<html"];

/* after */
r = [self rangeOfString: @"<!doctype" options: NSCaseInsensitiveSearch];
if (r.length == 0)
  r = [self rangeOfString: @"<html" options: NSCaseInsensitiveSearch];
```

For a large HTML body this removes one O(n) allocation + copy per save while
keeping identical semantics (case-insensitive literal search for the same two
needles). Covered by `test_isFullHTMLDocumentIsCaseInsensitive` and the other
`isFullHTMLDocument` tests in `Tests/Unit/TestNSString+Mail.m`, all green.

### 2. `fix(mailer): don't revert attachments committed by an earlier successful draft save`
`UI/MailerUI/UIxMailEditor.m` — the bug 6124 fix tracks uploaded attachment
names in the `savedAttachments` ivar and reverts them when a draft save fails.
The array was never cleared after a *successful* save, so within one editor
session (repeated saves / autosave) a later failure would also delete
attachment files belonging to the last good draft:

- save #1 uploads A, draft save succeeds → `savedAttachments = [A]` (committed)
- save #2 uploads B, draft save fails → both A and B deleted from the spool,
  corrupting the previously saved draft

One line in the success branch of `saveAction`, next to the existing
`attachmentAttrs = nil;` reset:

```objc
attachmentAttrs = nil;
[savedAttachments removeAllObjects];
```

Reverting now only ever touches attachments persisted by the failed save
itself, which is the intent of the 6124 fix.

## What I reviewed and deliberately left alone

- **`iCalEvent+ActiveSync.m`** (6156/6132): the new
  `_activeSyncRepresentationOfDate:inContext:` / `hasActiveSyncScheduleChange`
  helpers replace the previously duplicated StartTime/EndTime wire-format
  blocks; declarations, colon alignment and retain style match the file. No
  duplicated `userTimeZone` fetch worth folding (one call is behind the
  all-day branch).
- **`SOGoActiveSyncDispatcher+Sync.m`**: `itemStatus` reset per change, read
  once at emission — correct; the mixed tabs/spaces in the new block match the
  already-inconsistent neighbourhood, so no whitespace-only churn.
- **`SOPE/NGCards/iCalPerson.m`**: `roleWithDefault` mirrors the pre-existing
  `partStatWithDefault` exactly (good consistency).
- **`NGVCard+SOGo.m`** (6143): `_valuesForType:inArray:excluding:` follows the
  sibling `_simpleValueForType:` structure; `_simpleValueForType:` still has
  live call sites (emails, URLs) so it is *not* dead code. The
  `workPhones`/`homePhones` hoisting actually removes redundant lookups.
- **`SOGoContactSourceFolder.m`** (6161), **`iCalEntityObject+SOGo.m`**
  (6144/6131), **`SOGoDraftObject.m`** (6114/6124): minimal, consistent with
  surrounding GNUstep style; `attachAsString` dead branch and its variables
  were already removed by the fix itself.
- **Tests**: new files use per-file fixture helpers (`_eventWithContent:`,
  `_attendeeEvent`, `_cardWithSource:`) rather than copy-pasted blobs; the
  duplicated `LoadAppointmentsBundle()`/`LoadContactsBundle()` statics follow
  the suite's pre-existing pattern (5+ older files do the same), so factoring
  them would be churn beyond this diff. The 6135 HTML skeleton appears in both
  `TestNSString+Mail.m` and `TestNSData+Mail.m`, but the two files exercise
  different layers (parser vs sanitizer); sharing would require new cross-file
  test infrastructure for two short literals — not worth it.
- **`Tests/Unit/GNUmakefile`**: additions are the minimum needed (ActiveSync
  sources + Appointments link), mirroring the existing structure.

## Test results

`local/run-worktree-tests.sh wt/c14-clean` (after this pass):

```
Ran 193 tests
FAILED (2 failures, 0 errors)
```

The 2 failures are the documented host-noise ones (`test_NGInternetSocketAddressFromString`,
`test_stringWithoutHTMLInjection`) — same as a clean tree, no regressions.

(Note: the worktree was missing the untracked `config.make`; copied from the
main checkout to build, as the other worktrees already had.)
