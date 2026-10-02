# Bug 6135 — Malformatted emails when composed as HTML in webmail

Branch: `fix-6135-mantis` (commit `8c6cee74a`)

## Investigation summary

The reporter (SOGo 5.12.1) sees leftover broken tags in HTML-composed mail:
`html>` (report 1) then `p>guckst Du hier` (report 2), in **both** the
`text/plain` and `text/html` parts of the delivered message. The received
message shown in the ticket contains the exact full-page skeleton
`<html><head>\n<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
</head><body><img …tracking pixel…><p>guckst Du hier</p></body></html>`
(WebKit/Mac-Mail clipboard signature), i.e. the editor text that the browser
posted already contained the mangled `p>` (a lone `<` was dropped in the
browser-side editor round-trip of that full-page content; the plain part is
derived from it verbatim by `htmlToText`, which correctly keeps `p>` as text).

Reproductions performed **read/write on the e2e stack** (artifacts
`test-6135-*`, all cleaned up afterwards — INBOX/Drafts/Sent of
sogo-tests1/2 purged and verified empty):

1. SMTP-injected a copy of the ticket message, forwarded it through the real
   AngularUI (playwright/chromium): draft `/edit` text is **clean**
   (`<p>guckst Du hier</p>` intact, `charset=` stripped by
   `sanitizedContentUsingVoidTags`), delivered message **clean**.
2. Pasted the ticket HTML verbatim into the composer through the real UI
   (clipboard `text/html`): delivered message **clean**.
3. Replayed the HTTP save+send round trip (`POST …/save` + `POST …/send`)
   with the ticket HTML: delivered message contains the **reproducible
   server-side malformation**: the html part starts with `<html><html><head>`
   and ends with `</html></html>`.

Conclusion: the exact single-`<` drop of 5.12.1 happens in the browser
editor round-trip and could not be reproduced on `experimental` (the shipped
CKEditor build is byte-identical to 5.12.1, but the current compose pipeline
round-trips cleanly in every flow tested). The bug that *is* reproducible on
the current code — and that turns any full-document editor text into
malformed outgoing HTML — is the unconditional `<html>…</html>` wrap on
save: `-[UIxMailEditor _saveRequestInfo]` wraps whatever the client posts,
even when it is already a complete HTML document, producing nested `<html>`
tags in the stored draft and in the sent message. That malformed markup is
what makes strict mail clients surface leftover tag text.

## Root cause (file:line)

- `UI/MailerUI/UIxMailEditor.m:638` — `-[UIxMailEditor _saveRequestInfo]`
  unconditionally wraps the posted editor text in a second
  `<html>…</html>` when composing HTML (and likewise at :635 for the
  font-size variant), so a client that posts a full HTML document (pasted
  signature/clipboard round-trip failing client-side, API clients) yields
  `<html><html><head>…</body></html></html>` in the sent part.
- Contributing (verified innocent of the `<` drop, locked by tests):
  `SoObjects/Mailer/NSData+Mail.m:245`
  (`sanitizedContentUsingVoidTags:` — strips `charset=`, repairs `</br>`,
  moves `</html>` to the end) and `SoObjects/Mailer/NSString+Mail.m:588`
  (`htmlToText` — builds the text/plain alternative from the editor text,
  which is why the plain part showed the same `p>` leftover).

## What changed

- **Before** — posting a full document as editor text:
  stored/sent html part: `<html><html><head>…</body></html></html>`
- **After** — `-[NSString isFullHTMLDocument]` (new, `NSString+Mail`) detects
  documents that already carry a `<!doctype`/`<html>` tag;
  `_saveRequestInfo` stores them as-is and keeps wrapping only real
  fragments (`<html>%@</html>` / font-size `<span>` wrap unchanged for
  fragments).

Minimal diff: 3 production files (`NSString+Mail.h/.m`, `UIxMailEditor.m`),
no comments, GNUstep manual retain/release style respected (new code needs
none — pure string checks).

## Tests

- New `Tests/Unit/TestNSString+Mail.m` (registered in `Tests/Unit/GNUmakefile`):
  - `test_isFullHTMLDocumentWithHtmlTag` / `…WithDoctype` / `…IsCaseInsensitive` / `…WithFragment`
    (covers every branch of the new predicate)
  - `test_htmlToTextKeepsParagraphOfTicket6135` — the ticket HTML
    (meta + tracking img + `<p>guckst Du hier</p>`) converts to plain text
    with **no `p>`/`html>` leftover** (locks the text/plain side of the ticket)
  - `test_htmlByExtractingImagesKeepsParagraphOfTicket6135` — send-path
    re-serialization keeps `<p>guckst Du hier</p>` intact
  - `test_htmlByExtractingImagesExtractsDataURL` — inline data-URI extraction
    still works (`cid:` rewrite)
- `Tests/Unit/TestNSData+Mail.m`:
  - `test_ticket6135ForwardedSkeletonKeepsParagraphTag` — the compose
    pre-parser (`sanitizedContentUsingVoidTags:`) output on the ticket
    skeleton is locked byte-for-byte (charset stripped, `</html>` moved to
    the end, `<p>` intact)
- Suite: `Ran 180 tests — FAILED (2 failures)` where the 2 failures are the
  documented host-noise (`test_NGInternetSocketAddressFromString`,
  `test_stringWithoutHTMLInjection`). Full bundle build verified
  (`SoObjects/Mailer`, `UI/SOGoUI`, `UI/MailerUI` link cleanly).

## Verification steps for the orchestrator

Unit suite (already green on this worktree):

```
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
  /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c13-6135
# expect: Ran 180 tests, only the 2 known host-noise failures
```

End-to-end (after the next stack rebuild, since deploys are orchestrator-only):

```
# login
curl -s -c /tmp/cj -X POST http://127.0.0.1:50001/SOGo/connect \
  -H 'Content-Type: application/json' \
  -d '{"userName":"sogo-tests1","password":"sogo","captcha":""}' > /dev/null

# forward the ticket-shaped message (subject test-6135-fwsource must be
# SMTP-injected first) and fetch the generated draft
curl -s -b /tmp/cj -H 'Accept: application/json' \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/folderINBOX/<UID>/forward
curl -s -b /tmp/cj -H 'Accept: application/json' \
  'http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/folderDrafts/<draftId>/edit'
# -> "text" contains <p>guckst Du hier</p> (no "p>")

# save+send a full-document editor text, then read sogo-tests2's INBOX over
# IMAP (:1430): the text/html part must contain exactly one "<html" and one
# "</html>" (pre-fix it started with <html><html>)
```

Manual UI check (playwright/chromium, as done during investigation): forward
or paste-flow of the ticket HTML — both parts of the delivered message must
show `guckst Du hier` with no visible `p>`/`html>` leftovers.

## PR body draft

When a message is composed as HTML in the webmail, SOGo wraps the editor
content in `<html>…</html>` before storing the draft. If the browser posts a
complete HTML document instead of a body fragment — typically a full-page
pasted signature such as the Sendinblue/Outlook template from bug 6135, which
carries its own `<html><head><meta charset…></head><body>` skeleton and a
tracking pixel — the saved draft and the sent message end up with nested
`<html><html><head>…</html></html>` markup. Strict mail clients then surface
leftover tag text such as `html>` or `p>guckst Du hier` at the top of the
message, in the HTML part as well as in the text/plain alternative (which is
generated from the same editor text).

**AVANT** — html part of a message composed with a full-page signature:
`<html><html><head>\n<meta http-equiv="Content-Type" content="text/html;
charset=utf-8"></head><body><img …>…</body></html></html>` (nested `<html>`,
duplicated closing tag; recipients may display `html>` / `p>` leftovers).

**APRÈS** — the draft editor text is stored untouched when it already is a
full HTML document, so the sent part keeps a single root:
`<html><head>…</head><body><img …><p>guckst Du hier</p></body></html>`, and
body fragments keep being wrapped exactly as before (font-size wrap
included). The compose pipeline (pre-parse sanitizer, HTML→text alternative,
inline-image extraction) is now covered by unit tests using the exact HTML
from the ticket, locking that no `p>`/`html>` leftover is produced
server-side.
