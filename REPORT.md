# Fix for Mantis #6239 — attachments swapped when two users send concurrently from the same mailbox

Branch: `fix-6239-mantis` (worktree `wt/c36-6239`)

## Root cause (file:line)

- `SoObjects/Mailer/SOGoDraftsFolder.m:28-51` (pre-fix) — `generateNameForNewDraft`
  built the draft name `newDraft<unixtime>-<n>` from **file-static, process-local**
  state (`lastNew` / `newCount`), with a non-atomic read-modify-write.
- sogod runs **preforked** (`-WOWorkersCount N`; verified on the e2e stack:
  1 parent + N children) and each worker also dispatches connections on
  separate threads (SOPE `WOHttpAdaptor` `detachNewThreadSelector` when
  `maxThreadCount > 1`). Two compose requests for the same account that land on
  two different workers within the same wall-clock second therefore both mint
  `newDraft<ts>-1`. The reporter's access log proves exactly this: **both**
  browsers POST their send to the same path
  `POST /SOGo/so/info@abc.aa/Mail/0/folderDrafts/newDraft1787734448-1/send`
  (Chrome/152 at 11:54:41 and Chrome/151 at 11:54:44).
- Consequence — the two compose sessions share **one** draft object:
  - `SoObjects/Mailer/SOGoDraftObject.m:175-184` — the draft's attachment
    spool dir is `<userSpool>/<nameInContainer>`; with identical names both
    users' uploads land in the same directory (`saveAttachment:withMetadata:`,
    SOGoDraftObject.m:1258).
  - `fetchAttachmentAttrs` / `mimeMessageForRecipient:` compose the outgoing
    message from **every file in that directory** (SOGoDraftObject.m:1224), so
    each send picks up the other session's attachment (swap/mix depending on
    upload/autosave interleaving), and each autosave/send marks the previous
    shared IMAP draft copy deleted (SOGoDraftObject.m:620-621, 2388-2389).
- The name is only consumed as an opaque id (`lookupName:` checks
  `hasPrefix:@"newDraft"`, the Angular frontend round-trips `draftId`
  verbatim in every draft URL: `Message.service.js:159-161`), so embedding the
  pid in the name is safe.

This is a genuine server-side bug (random reproducibility = requires the same
second + distinct workers, as in the ticket).

## What changed (before/after)

`SoObjects/Mailer/SOGoDraftsFolder.m` — `generateNameForNewDraft`:

```objc
/* BEFORE */
currentTime = [[NSDate date] timeIntervalSince1970];
if (currentTime == lastNew) newCount++;
else { lastNew = currentTime; newCount = 1; }
newName = [NSString stringWithFormat: @"newDraft%u-%u", currentTime, newCount];

/* AFTER */
[nameLock lock];
if (currentTime == lastNew) newCount++;
else { lastNew = currentTime; newCount = 1; }
newName = [NSString stringWithFormat: @"newDraft%u-%u-%u",
                    currentTime, (unsigned int) getpid (), newCount];
[nameLock unlock];
```

- the counter update **and** the name formatting are serialized by a new
  static `NSLock` (created in `+initialize`, same pattern as
  `SOGoDraftObject.m:113`) — fixes the in-worker thread race;
- the name now embeds the worker's `getpid()` — fixes the cross-worker
  collision, which is what the ticket log shows.

Supporting changes:
- `SoObjects/Mailer/SOGoDraftsFolder.h` — declare `generateNameForNewDraft`.
- `Tests/Unit/TestSOGoDraftsFolder.m` (new) + registration in
  `Tests/Unit/GNUmakefile`.

## Tests

`Tests/Unit/TestSOGoDraftsFolder.m` — 4 tests:

1. `test_generateNameForNewDraftFormat` — locks the naming contract:
   `newDraft` prefix, 3 numeric components, pid component equal to `getpid()`,
   distinct names with the counter incrementing within one second.
2. `test_generateNameForNewDraftResetsCounterOnNewSecond` — covers the
   second-rollover branch (counter resets to 1).
3. `test_generateNameForNewDraftIsThreadSafe` — 4 threads generating 100
   concurrent names in one worker; all must be distinct (this is the test that
   caught the first version of the fix formatting the name outside the lock).
4. `test_generateNameForNewDraftIsUniqueAcrossProcesses` — **the 6239
   reproducer**: forks two children (simulating two preforked sogod workers)
   that each generate a name in the same second and report it over a pipe;
   asserts both epochs align and the two names differ.

Red/green validation: with the pre-fix `SOGoDraftsFolder.m` restored, tests
1, 3 and 4 FAIL (plus the rollover test errors); with the fix, the whole
suite passes (`Ran 270 tests — OK`), verified over 5 consecutive runs.

## Verification steps for the orchestrator

- Unit suite (host): 
  `/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c36-6239`
  → expect `Ran 270 tests / OK` (known host noise: `test_NGInternetSocketAddressFromString`,
  `test_stringWithoutHTMLInjection` may fail — did not in my runs).
- After the stack is rebuilt/deployed from this branch (orchestrator-only),
  the live repro of the AVANT behavior (fails on old build, passes on new):
  1. log in via the web UI in two different browsers as the **same user**
     (e2e: `sogo-tests1` / `sogo`);
  2. open a compose window in both within the same second (e.g. two
     `GET /SOGo/so/sogo-tests1/Mail/0/compose` fired concurrently — the e2e
     httpd is at `http://127.0.0.1:50001`; UI actions need the session cookie
     from `POST /SOGo/connect`, basic auth only works for DAV);
  3. check the returned `draftId` in each response: identical on the old build
     (both `newDraft<ts>-1`), distinct (`newDraft<ts>-<pid>-N`) on the new one;
  4. attach different files in each window and send both: on the old build the
     messages cross-pollinate attachments; on the new build each message
     carries only its own file.
  Note: on the currently running (stale, cycle-35) container the UI session
  cookie 403s for JSON actions — verify on the freshly rebuilt stack.

## PR body draft

When two users compose and send emails at the same time from the same
mailbox, the attachments of one message end up attached to the other
message. The cause is on the server: new draft names
(`newDraft<unixtime>-<counter>`) were generated from process-local statics,
while sogod runs preforked workers (and threaded request dispatch). Two
compose sessions landing on two workers within the same second received the
**same** draft name — the reporter's log shows both browsers sending via
`.../folderDrafts/newDraft1787734448-1/send` — and therefore shared a single
draft: one spool directory for attachments, one IMAP draft object, so every
send composed its message from both users' files.

AVANT: `newDraft1787734448-1` (worker A) == `newDraft1787734448-1`
(worker B) → shared spool → File A attached to recipient B's mail and
vice-versa (bug 6239).
APRES: `newDraft1787734448-4180-1` (worker A, pid 4180) vs
`newDraft1787734448-4183-1` (worker B, pid 4183) → distinct draft objects,
each message carries only its own attachments.

The generator now serializes its counter behind a lock (also fixing the
in-worker thread race, where the name was formatted outside the critical
section) and embeds the worker pid in the name, which keeps the
`newDraft<epoch>` prefix contract used everywhere (`lookupName:` prefix
match, opaque `draftId` on the Angular side). Covered by 4 new unit tests in
`Tests/Unit/TestSOGoDraftsFolder.m`, including a fork-based reproducer that
fails on the previous implementation.
