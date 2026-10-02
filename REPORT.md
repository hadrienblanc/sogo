# Bug 6114 — Changing encoding of a TXT file (fix report)

Worktree: `wt/c14-6114` — branch `fix-6114-mantis` — commit `48868446d`
`fix(mailer): preserve attachment file bytes end to end (bug 6114)`

## Root cause (file:line)

Uploading a `.txt` (or any `text/*`) attachment destroyed its bytes through a
lossy UTF-8 → Latin-1 → UTF-8 round trip, in three stacked places:

1. **Upload (the corruption)** — SOPE's multipart request parser decodes every
   `text/plain` part into an `NSString` before SOGo sees it:
   `sope-mime/NGMime/NGMimeBodyParser.m:51` (`NGMimeTextBodyParser` — no charset
   → strict UTF-8 first, then **Latin-1 fallback** which never fails). For a
   windows-1251 file the UTF-8 decode fails, Latin-1 "succeeds", and the
   original bytes become irrecoverable codepoints (`0xCE 0xCE 0xCE` "ООО" →
   `U+00CE U+00CE U+00CE` "ÎÎÎ").
2. **Spooling** — `UIxMailEditor.m:592` (`_saveAttachments`) passed that
   NSString to `SOGoDraftObject saveAttachment:withMetadata:`
   (`SoObjects/Mailer/SOGoDraftObject.m:1258`) which declares `NSData *` but
   got a string; `[_attach writeToFile:atomically:]` then serialized it as
   **UTF-8**. The draft spool file now permanently contains
   `C3 8E C3 8E C3 8E…` (latin1-decoded text re-encoded as UTF-8) — exactly the
   `problem.txt` mojibake from the ticket, and exactly what the reporter saw as
   "encoding changed to windows-1252" (mojibake rendered after a latin1→utf8
   mislabel).
3. **Composition (fragile, locale-dependent)** —
   `SoObjects/Mailer/SOGoDraftObject.m:1566-1583`
   (`bodyPartForAttachmentWithName:`, the `attachAsString` branch carrying the
   in-code `TODO: is this really necessary?`) re-decoded the spooled file with
   `[NSString defaultCStringEncoding]` and let NGMime re-encode it with the
   charset parameter of the stored content-type (or `defaultCStringEncoding`,
   `NGMimeTextBodyGenerator.m:59-66`). Whenever the decode and re-encode
   charsets disagree (server locale vs declared charset), the bytes are
   transcoded a second time.

Verified live on the shared stack (pre-fix): a cp1251 `.txt` uploaded to a
draft and saved produced the part
`Content-Type: text/plain` + `Content-Transfer-Encoding: quoted-printable` +
`=C3=8E=C3=8E=C3=8E…` in `viewsource` — byte-for-byte the ticket's
`problem.txt` mojibake. Reproduced standalone on the host by feeding the same
multipart request to `NGHttpMessageParser`: the `text/plain` file part body
arrives as a `GSCBufferString` (`c3 8e c3 8e …`), while an
`application/octet-stream` part body stays raw `NSData`.

The ticket IS a real bug (severity major, always reproducible for non-UTF-8,
non-latin1 text files). Other mailers don't corrupt because they never decode
attachment file parts as strings.

## What changed (before/after)

| Where | Before | After |
| --- | --- | --- |
| `UI/WebServerResources/js/Common/angular-file-upload.trump.js` (+ committed min bundle) | mail attachment uploads sent the `File` as-is, so browsers labeled the part `text/plain` and SOPE string-decoded it | for `alias == 'attachments'` the file is wrapped in an `application/octet-stream` `Blob` (bytes opaque to the parser) and the browser-provided type travels in a new `attachmentMimeType` form field; other uploaders (Contacts/Scheduler/Preferences) untouched; XSRF behavior unchanged |
| `UI/MailerUI/UIxMailEditor.m:533` (`_scanAttachmentFilenamesInRequest`) | sidecar mimetype = the multipart part's content-type (octet-stream under the new protocol) | reads the `attachmentMimeType` field (string or raw-data part) and uses it as the stored mimetype; no field → legacy behavior (part content-type), so old cached JS keeps working exactly as before |
| `SoObjects/Mailer/SOGoDraftObject.m:1271` (`saveAttachment:withMetadata:`) | an NSString body was silently written as UTF-8 by `writeToFile:` | explicit normalization: NSString body → `dataUsingEncoding:NSUTF8StringEncoding` (byte-identical to the old behavior, but the NSData contract is now enforced); also covers legacy string bodies from the forward/reply paths |
| `SoObjects/Mailer/SOGoDraftObject.m:1517` (`bodyPartForAttachmentWithName:`) | `text/plain`/`text/html` attachments were decoded with `defaultCStringEncoding` into NSStrings and re-encoded by the generator (charset guessing) | branch removed (TODO answered): every stored attachment is composed from its raw bytes — `message/rfc822` stays 8bit, everything else base64 — byte-for-byte, content-type passed through verbatim, no invented charset |

AVANT (observed on the stack, and matching `problem.txt` from the ticket):

```
Content-Type: text/plain
Content-Disposition: attachment; filename="original.txt"
Content-Transfer-Encoding: quoted-printable

Card;24/02/2025;01;=C3=8E=C3=8E=C3=8E =C3=81=C3=B0=C3=B3=C3=B1=C3=AA=C3=AE…
```

APRÈS (protocol sends octet-stream + `attachmentMimeType: text/plain`):

```
Content-Type: text/plain
Content-Disposition: attachment; filename="original.txt"
Content-Transfer-Encoding: base64

Q2FyZDsyNC8wMi8yMDI1OzAxO8HOAMHQ860K…
```

`base64 -d` of the part returns the original windows-1251 bytes; recipients
(and Notepad with auto-detection) see the correct text, like with other
clients.

## Tests

- `Tests/Unit/TestSOGoDraftObject.m` (extended, runs in the standard suite):
  - `test_textAttachmentBytesArePreserved` — cp1251 payload saved as
    `text/plain`; the composed message declares `base64`, keeps
    `Content-Type: text/plain` with **no invented charset**, and the parsed
    part body equals the original bytes exactly.
  - `test_declaredAttachmentCharsetIsPassedThrough` — a stored
    `text/plain; charset=windows-1251` sidecar is passed through verbatim with
    no transcoding of the bytes.
  - `test_saveAttachmentWithStringBodyPersistsUTF8Bytes` — legacy NSString
    bodies persist as UTF-8 (locks the normalization branch).
  - The message is re-parsed with a raw-body parser delegate
    (`TestRawBodyParser`/`TestRawBodyParserDelegate`) so assertions are on
    wire-level bytes, not on re-decoded strings.
- `Tests/spec/MailerAttachmentUploadSpec.js` (new jasmine spec, no stack
  needed): mailer uploads are wrapped as octet-stream carrying the real type
  in `attachmentMimeType`, empty browser types default to octet-stream,
  non-mailer uploaders and the XSRF header are untouched.
- Full worktree unit suite: `local/run-worktree-tests.sh wt/c14-6114` →
  **193 tests, 2 failures** — both known host noise
  (`test_NGInternetSocketAddressFromString`,
  `test_stringWithoutHTMLInjection`). (A pre-existing exit-time segfault after
  the summary also occurs on the pristine baseline; not related.)

## Verification steps for the orchestrator

After deploying this branch to the e2e stack (rebuild + volume reset, as
usual). The new-browser flow can be simulated with curl by sending the part as
`application/octet-stream` plus the `attachmentMimeType` field (exactly what
the patched JS now sends):

```bash
# 0) auth
cd /tmp && curl -s -c /tmp/cj -X POST -H 'Content-Type: application/json' \
  -d '{"userName":"sogo-tests1","password":"sogo"}' http://127.0.0.1:50001/SOGo/connect

# 1) new draft handle
DRAFT=$(curl -s -b /tmp/cj http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/compose)
# -> {"mailboxPath":"Drafts","draftId":"newDraft…","accountId":"0"}

# 2) cp1251 sample file
python3 -c "open('/tmp/test-6114.txt','wb').write('Card;ООО Бруско\nEND;18\n'.encode('cp1251'))"

# 3) upload simulating the patched uploader (octet-stream part + real type field)
UID=$(curl -s -b /tmp/cj -X POST \
  "http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/folderDrafts/newDraft1790914683-1/save" \
  -F 'attachmentMimeType=text/plain' \
  -F "attachments=@/tmp/test-6114.txt;type=application/octet-stream;filename=test-6114.txt" \
  | sed -n 's/.*"uid":"\([0-9]*\)".*/\1/p')

# 4) save draft content, then inspect the composed message source
curl -s -b /tmp/cj -X POST \
  "http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/folderDrafts/$UID/save" \
  -H 'Content-Type: application/json' \
  -d '{"to":["sogo-tests1@example.org"],"from":"Dude <sogo-tests1@example.org>","subject":"test-6114","text":"hello","isHTML":0}'
curl -s -b /tmp/cj "http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/folderDrafts/$UID/viewsource"
```

Expected in the source: `Content-Type: text/plain`,
`Content-Transfer-Encoding: base64`, and
`grep -A2 filename=\"test-6114.txt\" | tail -1 | base64 -d` on the part body
returns the original cp1251 bytes (`Card;ООО Бруско` when decoded as cp1251).
Pre-fix, the same flow with a `text/plain` part produced the
`=C3=8E…` quoted-printable mojibake (captured during reproduction).

Legacy compatibility (old cached JS): repeat step 3 without the
`attachmentMimeType` field and with `type=text/plain` on the part — the
attachment is still accepted and composed (old string behavior preserved).

Cleanup afterwards: `curl -s -b /tmp/cj -X POST .../folderDrafts/$UID/delete`
(test-6114-* artifacts only).

## PR body draft

Uploading a text file (e.g. a windows-1251 report `.txt`) as a mail
attachment re-encoded it as UTF-8 mojibake ("ООО Бруско" became "ÎÎÎ
Áðóñêî"), and the received/saved copy was unreadable. Other mail clients were
not affected. Root cause: SOPE's multipart request parser decodes `text/plain`
parts into strings (UTF-8-then-Latin-1 guess); SOGo then spooled that string
as UTF-8 (`UIxMailEditor` → `saveAttachment:withMetadata:`) and re-decoded it
at composition time with the server's locale charset
(`bodyPartForAttachmentWithName:` `attachAsString` branch — lossy on every
 hop where the charsets disagree).

The uploader now sends mail attachment bytes as an opaque
`application/octet-stream` part (real type in a new `attachmentMimeType`
field, honored by `UIxMailEditor`), `saveAttachment:` normalizes legacy
string bodies to UTF-8 explicitly, and the compose path no longer decodes
stored attachments as strings at all: every attachment is emitted from its raw
bytes (base64, or 8bit for `message/rfc822`) with its declared content-type
passed through verbatim. Non-UTF-8 text files now survive byte for byte, and
recipients' charset auto-detection behaves like in other clients. The wire
format change is additive: old cached front-ends keep working through the
previous path. Covered by three new unit tests in `TestSOGoDraftObject.m`
(byte-exact composition, charset passthrough, string-body normalization) and
a new jasmine spec for the uploader decorator.
