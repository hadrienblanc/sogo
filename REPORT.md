# Bug 6152 — Incorrect display of signature with SVG image

**Verdict: NOT A BUG (intentional security behavior).** Tests-only change — no
production code was modified.

## Root cause

There is no defect in the send path. When a message containing
`<img src="data:image/svg+xml;base64,...">` (the case of this ticket's HTML
signature) is sent, `htmlByExtractingImages:` extracts the payload as a proper
inline `image/svg+xml` MIME part with a `cid:` reference
(`SoObjects/Mailer/NSString+Mail.m:280-387`). The sent message is well-formed —
which is why it "displays normally in many other web interfaces", as the
reporter notes. This was confirmed live on the e2e stack (see Verification).

What the reporter sees in SOGo's own reader is a deliberate, three-layer XSS
defense (SVG documents can embed `<script>`), matching the administrator's
feedback on the ticket (~0018355: "this is on purposed because SVG file can
have executable code"):

| Symptom | Code |
| --- | --- |
| empty rectangle (cid never resolved) | `UI/MailerUI/UIxMailView.m:227-237` — SVG/XML attachments are excluded from `attachmentIds`, so the `cid:` in the HTML body has no resolvable URL and the display sanitizer drops the `src` attribute |
| shown as an attached file | `UI/MailPartViewers/UIxMailRenderingContext.m:226-227` — subtype `svg+xml` is forced to the link viewer, never the image viewer |
| XSS neutering when fetched | `SoObjects/Mailer/SOGoMailBodyPart.m:524-527` — body parts whose type contains xml/html/css/javascript are served as `text/plain` |

The editor displays the SVG only because CKEditor shows the raw `data:` URI in
an `<img>` context (a context where browsers never execute SVG scripts), and
`NGMimeBodyPart+SOGo.m:30-39` classifies `image/svg+xml` as an image for the
draft-reopen `cid:`→`data:` roundtrip.

## What changed

**Before:** none of the above behaviors were covered by tests; a future
refactor could silently start rendering SVG inline and re-open the XSS vector,
or drop SVG parts on send and break interop with other clients.

**After:** behavior locked by tests, no production change:
- `Tests/Unit/TestNSString+Mail.m` — new
  `test_htmlByExtractingImagesExtractsSVGDataURLOfTicket6152`: an SVG data URI
  from a signature is extracted on send as an `image/svg+xml` part, `src`
  rewritten to `cid:`, `type` attribute and dimensions preserved.
- `Tests/Unit/TestNGMimeBodyPart+SOGo.m` (new) — `isImage` accepts
  `image/svg+xml` (with and without parameters) and still rejects non-images.
- `Tests/Unit/TestUIxMailRenderingContext.m` (new, with a WOComponent mock) —
  `image/svg+xml` always selects the link viewer (with or without a body id),
  while `image/png` still selects the image viewer.
- `Tests/spec/MailSvgInlineImageSpec.js` (new e2e) — on a live stack: the cid
  reference of an inline SVG is not resolved in the HTML body, the part is
  presented as a downloadable attachment (link viewer), and fetching the part
  returns `text/plain`.
- `Tests/Unit/GNUmakefile` — registers the two new test files, links
  `UIxMailRenderingContext.m` into the test tool, adds `-I../../` for its
  `<SoObjects/...>` imports.

## Tests

Unit suite (before and after the change, worktree built with
`local/run-worktree-tests.sh`):

```
Ran 209 tests
FAILED (2 failures, 0 errors)
  test_NGInternetSocketAddressFromString   <- documented host noise
  test_stringWithoutHTMLInjection          <- documented host noise
```

All 8 new test methods pass (verified individually via `-f junit`):
`test_htmlByExtractingImagesExtractsSVGDataURLOfTicket6152`,
`test_isImageWithSVGMimeTypeOfTicket6152`, `test_isImageWithKnownImageMimeTypes`,
`test_isImageWithNonImageMimeTypes`, `test_svgImagesAreNeverRenderedThroughImageViewerOfTicket6152`,
`test_inlineSvgImagesAreRenderedThroughLinkViewerOfTicket6152`,
`test_plainImagesAreRenderedThroughImageViewer`, plus the e2e spec
`Mail inline SVG images (bug 6152)` (3 cases, self-cleaning mailbox
`test-6152-svg`, to be run by the orchestrator's jasmine pass on a rebuilt
stack).

## Verification steps for the orchestrator

1. Unit suite:
   `/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c16-6152`
   — expect 209 tests, only the two documented host-noise failures.

2. e2e jasmine (inside `sogo_dev`, rebuilt stack):
   `cd /workspace/Tests && sed -i 's/port: "50001"/port: "50000"/' lib/config.js && npx jasmine --config=spec/support/jasmine.json --filter "Mail inline SVG images (bug 6152)"` (restore `lib/config.js` afterwards).
   Note: on the *current* stack instance (restarted mid-cycle), sogod returns
   500 on DAV PUT into non-INBOX folders (stale folder cache, visible as
   doubled `folderfolder*` entries in PROPFIND); the spec follows the same
   makeCollection+PUT pattern as `MailHtmlRenderingSpec` and is expected to be
   green on a rebuilt stack.

3. Manual live reproduction (already executed, artifacts cleaned up —
   message deleted+expunged, folders removed):
   ```sh
   # deliver a message whose HTML body references cid:<id> with an inline
   # image/svg+xml part (e.g. via swaks/python to 127.0.0.1:2500), then:
   curl -s -c /tmp/c.txt -X POST http://127.0.0.1:50001/SOGo/connect \
        -H 'Content-Type: application/json' \
        -d '{"userName":"sogo-tests1","password":"sogo"}'
   curl -s -b /tmp/c.txt \
        http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/folderINBOX/<UID>/view
   # -> parts[].content for text/html shows <img width="391" height="232"/>
   #    WITHOUT any src (empty rectangle), and the image/svg+xml part is
   #    rendered by UIxMailPartLinkViewer with an /asAttachment/ download link
   curl -s -L -b /tmp/c.txt -o /dev/null -w '%{content_type}\n' \
        http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/folderINBOX/<UID>/1/2/2/sig.svg
   # -> text/plain  (scripts inside the SVG can never execute)
   ```

## PR body draft

Since 5.x, SOGo sends HTML-signature images as real MIME parts but deliberately
refuses to render inline SVG images in its own message view: SVG documents can
embed JavaScript, so resolving their `cid:` reference would let a crafted mail
execute script in the reader (bug 6152, see the administrator's note ~0018355).
Reported symptoms — empty rectangle plus an attached file in the Sent/received
view — are exactly this defense at work: the `cid:` stays unresolved
(`UIxMailView.m`), the part goes through the link viewer
(`UIxMailRenderingContext.m`), and it is served as `text/plain` when fetched
(`SOGoMailBodyPart.m`), so any embedded script is neutralized. The sent message
itself is standards-compliant and displays fine in mailers that render SVG
safely, which the reporter confirmed.

AVANT: a regression could silently re-enable inline SVG rendering (XSS) or drop
SVG parts on send (breaking interop), nothing locked these paths.
APRES: bug 6152 is closed as not-a-bug with the rationale recorded in tests:
unit tests lock the send-side extraction (`image/svg+xml` part + `cid:`
rewrite), the `isImage` classification used by the editor roundtrip, and the
viewer selection (SVG → link viewer, PNG → image viewer); an e2e spec locks the
full stack behavior — unresolved `cid:`, attachment-only presentation, and
`text/plain` serving of SVG parts.
