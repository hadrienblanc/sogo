# Fix for Mantis #6240 — non-root inline text/html part in multipart/related rendered as message body

Branch: `fix-6240-mantis` (worktree `wt/c36-6240`)

## Root cause (file:line)

- `UI/MailPartViewers/UIxMailRenderingContext.m:193-197` — `viewerForBodyInfo:` maps
  `multipart/related` to the **mixed** viewer, which is the correct generic renderer for
  multipart containers, but it carries no notion of the RFC 2387 root object.
- `UI/MailPartViewers/UIxMailPartMixedViewer.m:101` (`-renderedPart`) — the mixed viewer
  rendered **every** child part sequentially as visible content. For a non-root
  `text/html` child with `Content-Disposition: inline` (or with no disposition at all —
  inline is the RFC 2183 default), `viewerForBodyInfo:` selects the **HTML viewer**
  (`UIxMailRenderingContext.m:207-215`: a text part is only demoted to the link viewer
  when its disposition is explicitly `attachment`), so the related resource was appended
  to the visible message body. The AngularJS frontend (`Message.service.js`, `_visit`)
  renders every leaf of the mixed content array, which made the resource (and any CSS it
  carries: `position`, `z-index`, large backgrounds) visible below the real body.

Per RFC 2387, only the root object of `multipart/related` (the part designated by the
`start` parameter, defaulting to the first part) is the message body; non-root parts are
resources referenced by Content-ID.

## What changed (before/after)

**Before** (view JSON of the ticket reproducer, `multipart/related` root =
`multipart/alternative` + non-root inline `text/html`):

```json
{ "type": "UIxMailPartMixedViewer", "contentType": "multipart/related",
  "content": [
    { "type": "UIxMailPartAlternativeViewer", "...": "text/plain + text/html (real body)" },
    { "type": "UIxMailPartHTMLViewer", "contentType": "text/html",
      "content": "<div style=\"position:fixed;z-index:9999...\">RELATED RESOURCE..." }
  ] }
```
→ the second HTML viewer is appended to the visible body (bug, reproduced live on the
e2e stack before fixing).

**After**:

```json
{ "type": "UIxMailPartMixedViewer", "contentType": "multipart/related",
  "content": [
    { "type": "UIxMailPartAlternativeViewer", "...": "text/plain + text/html (real body)" },
    { "type": "UIxMailPartLinkViewer", "contentType": "text/html",
      "shouldDisplayAttachment": 1 }
  ] }
```
→ only the root object is rendered as body; the related text resource is downloadable
from the attachment strip, exactly like the already-correct `disposition: attachment`
case of the ticket's Test B. Images and non-text parts inside `multipart/related` keep
their previous rendering (CID images are still resolved through `attachmentIds`).

Minimal implementation:

1. `UIxMailPartMixedViewer.m:121-125` — when the container's subtype is `related`,
   resolve the root part index once; `UIxMailPartMixedViewer.m:139-142` — non-root
   children are rendered through the new `viewerForNonRootRelatedBodyInfo:` instead of
   `viewerForBodyInfo:`.
2. `UIxMailRenderingContext.m:298-309` — `viewerForNonRootRelatedBodyInfo:` demotes
   `text/plain`/`text/html` resources to the link (attachment) viewer; everything else
   falls through to the regular selection, so image/attachment handling is unchanged.
3. `UIxMailRenderingContext.m:312-335` — `rootPartIndexOfRelatedBodyInfo:` implements
   the RFC 2387 root resolution: the child whose `bodyId` matches the `start`
   `parameterList` entry (bracket-normalized), falling back to the first part (also when
   `start` is absent, unmatched, or the info has no `parts` — S/MIME decoded path).

## Tests

- Unit (`Tests/Unit/TestUIxMailRenderingContext.m`, already registered in
  `Tests/Unit/GNUmakefile`), 9 new tests:
  - root resolution: no `start` → first part; `start` matching a Content-ID (with and
    without angle brackets); unknown `start` → fallback to first part; empty related.
  - viewer selection: non-root `text/html` and `text/plain` of a related container →
    link viewer (ticket case); non-root non-text parts (image/png, multipart/alternative)
    keep their viewer; root text parts keep html/text viewers (guards against
    over-demotion).
- E2e (`Tests/spec/MailerRelatedInlinePartsSpec.js`, jasmine, auto-discovered):
  PUTs 4 messages via WebDAV (ticket Test A structure, Test B structure, classic
  related html-root + cid image, related with `start` parameter) and asserts on the
  `/view` JSON that exactly one HTML viewer (the root) is rendered as body and that
  related text resources render as link-viewer attachments. Its assertion logic was
  validated against the live stack before the fix (fails on old code: 2 HTML viewers)
  and against the post-fix JSON shape. The spec itself must run after the orchestrator
  deploys this branch (standard `npx jasmine` inside `sogo_dev`).

Full unit suite: **Ran 266 tests — OK** (only the known host-noise memcached/regex
warnings; no new failures).

## Verification steps for the orchestrator

After deploying this branch to the e2e stack:

1. Jasmine (inside `sogo_dev`):
   ```
   cd /workspace/Tests && sed -i 's/port: "50001"/port: "50000"/' lib/config.js && \
     npx jasmine --config=spec/support/jasmine.json --filter="Mail multipart/related rendering (bug 6240)"; \
     sed -i 's/port: "50000"/port: "50001"/' lib/config.js
   ```
   → 4 specs, 0 failures.
2. Curl A/B against the stack (reproduces the ticket's structure). Prepare
   `repro.eml` = the `relatedWithInlineResource` message embedded in
   `Tests/spec/MailerRelatedInlinePartsSpec.js`, then:
   ```
   COOKIE=$(curl -si -X POST http://127.0.0.1:50001/SOGo/connect -H 'Content-Type: application/json' \
             -d '{"userName":"sogo-tests1","password":"sogo"}' | grep -i '^set-cookie: 0xHIGHFLYxSOGo' | \
             sed 's/^[Ss]et-[Cc]ookie: //' | cut -d';' -f1)
   curl -s -o /dev/null -u sogo-tests1:sogo -X MKCOL http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Mail/0/test-6240-v
   curl -s -o /dev/null -u sogo-tests1:sogo -X PUT -H 'Content-Type: message/rfc822' \
        --data-binary @repro.eml \
        http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Mail/0/foldertest-6240-v/repro.eml
   curl -s -H "Cookie: $COOKIE" \
        http://127.0.0.1:50001/SOGo/so/sogo-tests1/Mail/0/foldertest-6240-v/1/view | \
     python3 -c '
   import json, sys
   flat = []
   def walk(part):
       if isinstance(part.get("content"), list):
           for child in part["content"]:
               walk(child)
       else:
           flat.append(part)
   walk(json.load(sys.stdin)["parts"])
   for p in flat:
       if p.get("contentType") in ("text/html", "multipart/related"):
           print(p.get("contentType"), "->", p.get("type"))
   '
   curl -s -o /dev/null -u sogo-tests1:sogo -X DELETE http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Mail/0/foldertest-6240-v
   ```
   Expected after the fix — exactly one HTML viewer, the related resource demoted to a
   link viewer:
   ```
   text/html -> UIxMailPartHTMLViewer
   text/html -> UIxMailPartLinkViewer
   ```
   Before the fix, both lines were `UIxMailPartHTMLViewer` (verified live during this
   session; the related resource carried `position:fixed;z-index:9999` into the body).
3. Unit suite: `local/run-worktree-tests.sh <worktree>` → 266 tests, OK.

## PR body draft

**AVANT** — SOGo rendait chaque partie d'un `multipart/related` comme contenu visible :
un `text/html` non racine avec `Content-Disposition: inline` (ou sans disposition) était
affiché sous le corps réel du message. Les CSS qu'il transporte (`position: fixed`,
`z-index`, arrière-plans) pouvaient recouvrir ou casser complètement l'affichage, alors
que Thunderbird n'affiche que l'objet racine (RFC 2387). Le contournement client était
impossible : la partie était injectée côté serveur dans le JSON de la vue.

**APRES** — Seul l'objet racine du `multipart/related` (paramètre `start`, sinon la
première partie) est rendu comme corps du message ; les ressources `text/plain` /
`text/html` non racines passent par le visualiseur de pièces jointes (téléchargeables,
comme pour le cas `disposition: attachment` déjà correct), et le comportement des
images CID et des autres types est inchangé. Le tout est couvert par 9 tests unitaires
sur la sélection du visualiseur et la résolution de la racine, plus une spec e2e qui
verrouille les quatre structures (ressource inline, ressource attachment, racine HTML +
image CID, paramètre `start`).
