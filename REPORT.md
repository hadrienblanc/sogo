# Bug 6124 — "Issue with Attachment Handling" (fix-6124-mantis)

## Verdict

Confirmed bug, server-side. When an uploaded attachment makes the draft exceed
`SOGoMaximumMessageSizeLimit`, the file is persisted to the draft's spool folder
*before* the draft save is attempted; when that save fails, neither the server
nor the web client ever deletes it. Every later save/send re-counts this phantom
file, so the draft stays permanently over the limit ("Message is too big") even
after the UI has dropped the attachment — matching the reporter's repro exactly.
The phantom file would even be *sent* with the message on a lucky retry.

## Root cause (file:line)

- `UI/MailerUI/UIxMailEditor.m:589` — `_saveAttachments` writes every uploaded
  file into the draft spool folder via `saveAttachment:withMetadata:`, then
  `saveAction` (`UI/MailerUI/UIxMailEditor.m:815`) calls `[co save]`.
- `SoObjects/Mailer/SOGoDraftObject.m:1622-1627` — `bodyPartsForAllAttachments`
  sums the sizes of **all files on disk** in the draft folder and returns nil
  when over the limit; `save` (`SOGoDraftObject.m:599-604`) then answers
  HTTP 500 `"Message is too big"`.
- `UI/WebServerResources/js/Mailer/MessageEditorController.js:151-161` —
  `onErrorItem` only removes the item from the UI queue; no server-side delete
  is issued (the client cannot even know the stored name, since the server
  renames on collision, e.g. `file.txt` → `file-1.txt`).

## What changed

**Before** (AVANT):
1. Upload 15 MB → `/save` → file persisted, draft saved to IMAP → OK.
2. Upload 12 MB → `/save` → file persisted → `[co save]` fails "Message is too
   big" → UI drops the item → **the 12 MB file stays in the spool folder**.
3. Upload 1 MB → `/save` → spool holds 15 + 12 + 1 MB → still "Message is too
   big". Send fails too. Only workaround: discard the whole draft.

**After** (APRÈS):
- `UIxMailEditor` tracks the attachment filenames persisted during the current
  request (`savedAttachments` ivar, filled in `_saveAttachments` only on
  successful writes).
- When `saveAction` ends on the error path (size limit, IMAP failure, SOPE
  upload exception…), it calls the new draft-object primitive
  `deleteAttachmentsWithNames:` to drop exactly those files, so the server
  state matches what the UI shows (upload rejected ⇒ attachment not attached).
- `SOGoDraftObject` gains `- (void) deleteAttachmentsWithNames: (NSArray *)`
  (a best-effort loop over the existing `deleteAttachmentWithName:`).
- Net effect: after the oversized upload is rejected, the next `/save` or
  `/send` is re-evaluated against the real remaining attachments; the draft is
  usable without rewriting anything.

Note: the forward/reply flows (`fetchMailForForwarding:`, etc.) are untouched —
they ignore save errors by design and their drafts were never stuck this way.

## Tests

`Tests/Unit/TestSOGoDraftObject.m` (Mailer bundle, no new file — reuses the
bug-6224 harness):

- `test_oversizedAttachmentRollbackRestoresMessage` — sets
  `SOGoMaximumMessageSizeLimit` to 1 KB, reproduces the ticket sequence at
  draft level: message buildable → oversized attachment persisted on disk →
  message no longer buildable ("too big" state) → rollback via
  `deleteAttachmentsWithNames:` → message buildable again, still carries the
  remaining attachment, reverted file does not leak.
- `test_deleteAttachmentsWithNamesToleratesMissingNames` — deletes several
  names, skips missing ones, tolerates an empty array.

Full suite: `Ran 190 tests, FAILED (2 failures)` — the two failures are the
documented host-noise ones (`test_NGInternetSocketAddressFromString`,
`test_stringWithoutHTMLInjection`). NB: `./obj/sogo-tests -f junit` segfaults
while *printing* the report; this is pre-existing on `experimental` (verified on
the main checkout) and unrelated — text mode is what the runner uses.

## Verification steps for the orchestrator

The e2e stack currently has no `SOGoMaximumMessageSizeLimit` and I may not
change config/restart, so the exact 500 could not be triggered live; endpoints
below were rehearsed read-only on the shared stack (draft + artifacts cleaned
up). After deploying this branch, add to `sogo.conf`:

```
SOGoMaximumMessageSizeLimit = 25;
```

then (jq available):

```bash
B=http://127.0.0.1:50001
C=/tmp/opencode/cj-6124.txt
curl -s -c $C -X POST $B/SOGo/connect -H 'Content-Type: application/json' \
     -d '{"userName":"sogo-tests1","password":"sogo"}'
# create draft
DRAFT=$(curl -s -b $C -H 'Accept: application/json' \
     $B/SOGo/so/sogo-tests1/Mail/0/compose | jq -r .draftId)
U=$B/SOGo/so/sogo-tests1/Mail/0/folderDrafts/$DRAFT
head -c 15000000 /dev/zero > /tmp/opencode/test-6124-a.bin   # 15 MB
head -c 12000000 /dev/zero > /tmp/opencode/test-6124-b.bin   # 12 MB
head -c 1000000  /dev/zero > /tmp/opencode/test-6124-c.bin   # 1 MB
# 1. 15 MB upload must succeed
curl -s -b $C -X POST -H 'Accept: application/json' \
     -F 'attachments=@/tmp/opencode/test-6124-a.bin' $U/save | jq .uid
# 2. 12 MB upload must fail with "Message is too big"
curl -s -b $C -X POST -H 'Accept: application/json' \
     -F 'attachments=@/tmp/opencode/test-6124-b.bin' $U/save | jq .message
# 3. AFTER the fix: 1 MB upload must now SUCCEED (was failing before the fix)
curl -s -b $C -X POST -H 'Accept: application/json' \
     -F 'attachments=@/tmp/opencode/test-6124-c.bin' $U/save | jq .uid
# 4. cleanup
curl -s -b $C -X POST -H 'Accept: application/json' $U/delete -o /dev/null -w '%{http_code}\n'
rm -f /tmp/opencode/test-6124-*.bin $C
```

Step 3 succeeding (HTTP 200 + uid, `lastAttachmentAttrs` present) is the
regression proof; on the unfixed code it returns
`{"message": "Message is too big"}`. The same invariant holds for
`.../send` after a rejected upload.

## PR body draft

Bug 6124 (major, Web Mail): with `SOGoMaximumMessageSizeLimit` set, an upload
that pushes the draft over the limit is persisted to the draft spool folder
before the draft save is attempted; when that save fails with "Message is too
big", the file is never removed — not by the server, and not by the web client,
which only drops the item from its upload queue. From then on every save/send
re-counts the phantom file, so the draft stays over the limit forever: adding a
tiny attachment still errors, and the only escape is discarding the whole draft.
The phantom file would even be included in the message if a later send
succeeded by other means.

AVANT — compose with a 25 MB limit, attach 15 MB (OK), then 12 MB: upload
rejected "Message is too big", attachment disappears from the editor; attach a
1 MB file: still "Message is too big"; sending impossible; draft must be
discarded and rewritten.

APRÈS — same scenario: the 12 MB upload is still rejected (the limit is the
limit), but the file is now rolled back from the spool when the save fails, so
the server state matches the editor; attaching the 1 MB file succeeds and the
message can be sent without rewriting anything. The rollback is wired on the
whole save-error path, so any failed save (IMAP hiccup included) no longer
leaves ghost attachments behind. Covered by new unit tests in
`Tests/Unit/TestSOGoDraftObject.m` reproducing the exact ticket sequence.
