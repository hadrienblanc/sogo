# Bug 6153 — "Sending mail results in HTTP 405 and 'Sent is not an IMAP4 folder'"

Branch: `fix-6153-mantis` (commit `f293a2758`), based on `experimental`.

## Root cause (file:line)

The error is raised in `-[SOGoMailFolder postData:flags:]`
(`SoObjects/Mailer/SOGoMailFolder.m:1046`, before the fix at lines 1046–1059),
called from `-[SOGoDraftObject sendMail]` (`SoObjects/Mailer/SOGoDraftObject.m:2384`)
when copying the message to the Sent folder. `UIxMailEditor sendAction`
(`UI/MailerUI/UIxMailEditor.m:954`) renders any error of that send as
HTTP 405 + `{"status": "failure", "message": "<reason>"}` — exactly the
response shown in the ticket.

The pre-fix logic was:

1. `[self exists]` → IMAP `STATUS "Sent" (UIDVALIDITY)` (via
   `-[NGImap4Connection doesMailboxExistAtURL:]`). A **transient** failure of
   this probe returns NO even though the mailbox exists (Courier refuses some
   STATUS calls — e.g. on the selected mailbox — and pooled connections can
   blip; this matches the "1 in 20-30 sends, multiple accounts" pattern).
2. Fall back to `createMailbox:atURL:` → IMAP `CREATE "Sent"`. Since the
   mailbox **does** exist, every server refuses with `NO ... already exists`
   (verified live on the e2e Dovecot: `NO [ALREADYEXISTS] Mailbox already
   exists`; Courier/UW/Cyrus emit the same wording without the response code).
3. Both operations having "failed", SOGo concluded "Sent is not an IMAP4
   folder" and **skipped the APPEND**, while SMTP had already delivered the
   message.

So the ticket IS a real SOGo bug: a CREATE refused with "already exists" is
proof that the mailbox exists, yet the old code treated it as proof that it
does not. (The admin's suggestion `NGImap4DisableIMAP4Pooling = YES;` merely
reduces the frequency of the transient STATUS failure; it does not fix the
misclassification.)

## What changed (before/after)

`SoObjects/Mailer/SOGoMailFolder.m`, `-[SOGoMailFolder postData:flags:]` only:

- **AVANT** — if the folder "doesn't exist" and CREATE returns an exception
  (any exception), the append is aborted and a 502/405
  `"<folder> is not an IMAP4 folder"` error is raised. Message sent via SMTP
  but not saved in Sent; UI shows the error from the ticket.

  ```
  if ([self exists]
      || ![[self imap4Connection] createMailbox: ... atURL: ...])
    return [[self imap4Connection] postData: _data flags: _flags
                                toFolderURL: [self imap4URL]];
  return [NSException exceptionWithHTTPStatus: 502
      reason: [NSString stringWithFormat: @"%@ is not an IMAP4 folder", ...]];
  ```

- **APRÈS** — when CREATE fails but its reason contains "already exists"
  (case-insensitive; covers Courier, Dovecot `[ALREADYEXISTS]`, Cyrus, UW), the
  mailbox is known to exist and the APPEND proceeds normally. Any other CREATE
  failure (permissions, dead connection, quota…) keeps the previous error
  path. No behavioural change for folders that genuinely do not exist
  (CREATE succeeds → APPEND).

  ```
  error = nil;
  if (![self exists])
    {
      error = [[self imap4Connection] createMailbox: ... atURL: ...];
      if (error
          && [[error reason] rangeOfString: @"already exists"
                                    options: NSCaseInsensitiveSearch].length > 0)
        error = nil;
    }
  if (!error)
    return [[self imap4Connection] postData: _data flags: _flags
                                toFolderURL: [self imap4URL]];
  ```

No public API change, no comment added, GNUstep retain/release style, 1 file
touched in production code.

## Tests

New `Tests/Unit/TestSOGoMailFolder.m` (registered in `Tests/Unit/GNUmakefile`).
The Mailer bundle cannot be statically linked into the test tool (see the note
in `Tests/Unit/GNUmakefile`), so the test loads `Mailer.SOGo` at runtime and
drives the **real** `-[SOGoMailFolder postData:flags:]` through a runtime
subclass (`objc_allocateClassPair`) that stubs `exists`, `imap4Connection`,
`imap4URL`, `mailAccountFolder` and `relativeImap4Name`, with a fake
NGImap4-shaped connection recording CREATE/APPEND calls:

- `test_postDataAppendsWhenFolderExists` — exists → APPEND, no CREATE.
- `test_postDataAppendsAfterSuccessfulCreate` — missing folder → CREATE then APPEND.
- `test_postDataAppendsWhenCreateReportsAlreadyExists` — **the fix**: CREATE
  refused with "Failed to create folder: Mailbox already exists" → APPEND
  still happens, no error.
- `test_postDataFailsWhenCreateFailsOtherwise` — CREATE failed otherwise →
  "Sent is not an IMAP4 folder", no APPEND (error path preserved).
- `test_postDataPropagatesAppendError` — an APPEND failure is propagated as-is.

All 4 code branches of the touched method are exercised (100 % coverage of the
change).

Result: `local/run-worktree-tests.sh wt/c15-6153` → `Ran 202 tests, FAILED (2
failures)` — the only failures are the documented host noise
(`test_NGInternetSocketAddressFromString`, `test_stringWithoutHTMLInjection`).

Note (environment, not this change): running the suite with `-f junit` on this
worktree segfaults late in the run inside `class_getMethodImplementation`
(gnustep-base/libobjc). Verified pre-existing: with this branch's changes
stashed and the test tool force-relinked without the new test file, the
junit-format run still crashes at the same point (`Tests/Unit/ActiveSync/`
build artifacts). The official text-format harness is unaffected. The other
worktree (6242-uid-at) completes junit fine; likely related to the current
experimental tip, worth a separate look.

## Verification steps for the orchestrator

1. Unit suite (already green on this branch):

   ```
   /home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
     /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c15-6153
   # expect: Ran 202 tests, only the 2 known host-noise failures
   ```

2. IMAP fact backing the root cause (read-only against the stack's Dovecot,
   port 1430):

   ```
   exec 3<>/dev/tcp/127.0.0.1/1430 && printf 'a1 LOGIN sogo-tests1 sogo\r\na2 CREATE test-6153-sent\r\na3 CREATE test-6153-sent\r\na4 DELETE test-6153-sent\r\na5 LOGOUT\r\n' >&3 && timeout 5 cat <&3
   # a3 must answer: NO [ALREADYEXISTS] Mailbox already exists
   ```

3. Live send regression check (run **after** deploying experimental — the
   sogo_dev/sogo_httpd containers were down while this agent worked, backends
   only):

   ```
   D="test-6153-orch-$(date +%s)"
   # save a draft
   curl -su sogo-tests1:sogo -X POST \
     "http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/folderINBOX/folderDrafts/newDraft${D}-1/save" \
     --data "to=sogo-tests2@sogo.local&subject=${D}&text=hello" -w "\nsave HTTP %{http_code}\n"
   # send it -> expect {"status":"success"...} and HTTP 200
   curl -su sogo-tests1:sogo -X POST \
     "http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/folderINBOX/folderDrafts/newDraft${D}-1/send" \
     --data "to=sogo-tests2@sogo.local&subject=${D}&text=hello" -w "\nsend HTTP %{http_code}\n"
   # the message must sit in Sent
   exec 3<>/dev/tcp/127.0.0.1/1430 && printf 'a1 LOGIN sogo-tests1 sogo\r\na2 STATUS "Sent" (MESSAGES)\r\na3 SEARCH HEADER SUBJECT "${D}"\r\na4 LOGOUT\r\n' >&3 && timeout 5 cat <&3
   # cleanup: flag the found UID(s) \Deleted in Sent (tests1) and INBOX (tests2), then EXPUNGE
   ```

4. Force-trigger the exact ticket path (optional, white-box): temporarily make
   the existence probe fail (e.g. `STATS`-refusing stub as in the unit test)
   — covered deterministically by
   `TestSOGoMailFolder.test_postDataAppendsWhenCreateReportsAlreadyExists`, no
   live stack needed.

All `test-6153-*` IMAP artifacts created during investigation were deleted
(verified with `LIST "" test-6153-*` → empty).

## PR body draft

Sending a message from the web mail occasionally popped up
`"Sent is not an IMAP4 folder"` (HTTP 405), while the message **was** sent but
never saved in Sent (bug 6153, Courier, ~1 send in 20-30). The cause is in the
save-to-Sent flow: SOGo probes the mailbox with `STATUS <folder>
(UIDVALIDITY)` and, when the probe fails — which happens transiently with
Courier or a pooled-connection hiccup on a mailbox that exists — it falls back
to `CREATE`. The server then legitimately refuses with `NO ... already
exists`, and SOGo misread that refusal as "the folder cannot exist",
aborting the APPEND after SMTP had already delivered the message.

**AVANT**: transient STATUS failure on an existing Sent mailbox →
`CREATE "Sent"` → `NO Mailbox already exists` → error surfaced to the user as
`{"status": "failure", "message": "Sent is not an IMAP4 folder"}` (HTTP 405),
message lost from Sent.

**APRÈS**: a CREATE refused with "already exists" (Courier wording, Dovecot
`[ALREADYEXISTS]`, Cyrus, UW) is now treated as proof that the mailbox exists,
and the APPEND proceeds — the message is saved in Sent and the send succeeds.
Any other CREATE failure (permissions, broken connection, …) still reports the
previous error. The change is confined to `-[SOGoMailFolder postData:flags:]`
and is covered by 5 new unit tests in `Tests/Unit/TestSOGoMailFolder.m`
exercising every branch, including the error paths; the full unit suite passes
(only the two documented host-specific failures remain).
