# Fix report — Mantis 6214 (branch `fix-6214-mantis`, commit `3b397622e`)

**Summary duplicated when switching identity in compose (regression from the 0005695/0006168 fix, commit 71d865b)**

## Root cause (file:line)

`UI/WebServerResources/js/Mailer/MessageEditorController.js`, `setFromIdentity()` (line 386).

When the From identity changes, the previous signature is located with a regexp and
replaced. Commit 71d865b (fix for 6168, layered on b7e529d for 5695) replaced the
original mode-aware pattern with:

```js
new RegExp('(<p>)?(<br ?\/?>(&nbsp;)?[ \\n]?)?--&nbsp;<br ?\/?>(&nbsp;)?[ \\n]?(<\/p>)?' + currentIdentity.signature)
```

Two regressions:

1. **Hardcoded HTML regardless of compose mode** — the function correctly computes
   `nl`/`reNl`/`space` per mode (`\n`/`' '` for plain text, `<br />`/`&nbsp;` for
   HTML) but the pattern ignored those variables. In plain text the draft body is
   `\n\n-- \n<sig>` while the pattern only matches `--&nbsp;<br />` → never matches →
   `previousIdentity` stays undefined → the fallback paths (append at end, or
   insert-before-quote) add the new signature **without removing the old one**.
2. **No regex escaping** — `currentIdentity.signature` was concatenated raw, so
   `. + ( ) / ?` from URLs and phone numbers alter or break the pattern (invalid
   regex → catch → plain append → duplication).

The `nl2`/`reNl2` variables added by 71d865b were dead code.

The ticket's analysis is confirmed. This is a real bug, 100% reproducible in plain
text mode (`SOGoMailComposeMessageType = text`).

## What changed (before/after)

`UI/WebServerResources/js/Mailer/MessageEditorController.js` (minimal diff, 3 hunks):

- Restored the mode-aware, escaped pattern, keeping the 5695 try/catch fallback:

```js
var escapedSignature = currentIdentity.signature.replace(/[-\[\]{}()*+?.,\\^$|#\s]/g, '\\$&');
if (vm.composeType == "html")
  escapedSignature = escapedSignature.replace(/<br(\\ | )?\\?\/?>/g, '<br ?\\/?>');
var currentSignature = new RegExp('(<p>)?(' + reNl + '){' + nlNb + '}--' + space + reNl + escapedSignature + '(<\/p>)?');
```

  - plain text: `(\n){2}-- \n<escapedSig>` → matches the draft exactly (ticket's suggested fix).
  - HTML: `(<p>)?(<br ?/?>(&nbsp;)?[ \n]?){2}--&nbsp;<br ?/?>(&nbsp;)?[ \n]?<sig>(</p>)?`
    - `reNl` changed `<br ?/>` → `<br ?/?>`: CKEditor 5 `getData()` serializes soft
      breaks as `<br>` (no trailing slash) — this was the part of 6168 that the
      original pre-71d865b pattern missed; keeping 71d865b's `<br ?\/?>` tolerance.
    - `(<p>)?` … `(</p>)?`: CKEditor 5 auto-paragraphs the signature block.
    - the escaped signature's own `<br />` markers are made normalization-tolerant
      (`<br(\\ | )?\\?\/?>` → `<br ?\/?>`) so a multi-line HTML signature written
      `<br />` still matches after the editor rewrote it to `<br>`.
- Removed the dead `var nl2, reNl2;` and the commented-out old code.
- `Mailer.services.js` / `Mailer.services.js.map`: regenerated with the same
  toolchain as the committed artifact (uglify-js 3.17.4, source order taken from the
  committed sourcemap; the pristine regeneration is byte-identical to the committed
  bundle, validating the toolchain before rebuilding with the fix).

AVANT (plain text, switch From personal → shared mailbox without signature):

```
\n\n-- \nRobert Frost\nCTO (Example) +33 1 23 45 67 89\nhttps://example.com/?from=sig
→ (switch) → signature stays, a second copy is appended on the next switch/typing
```

APRÈS:

```
\n\n-- \nRobert Frost\n…
→ (switch) → (empty body — previous signature and its "-- " marker fully removed)
```

## Tests

- New `Tests/spec/MailerIdentitySignatureSpec.js` — pure-node jasmine spec (no stack
  needed, style of `MailerMessageFlagsSpec.js`): loads the real
  `MessageEditorController.js` with a stubbed angular module registry, instantiates
  the controller and calls `setFromIdentity` directly. 8 specs:
  1. plain text: previous signature removed when switching to a signature-less identity (#6214 exact scenario)
  2. plain text: signature A → signature B replaced, `from` updated
  3. signaturePlacement `below` (nlNb=1) replaced
  4. HTML: untouched server draft (`<br />` + `&nbsp;`) replaced
  5. HTML: CKEditor 5-normalized draft (`<br>`, `<p>` wrappers, `<br />` vs `<br>` inside the signature) replaced (#6168)
  6. HTML: normalized signature removed when switching to a signature-less identity
  7. fallback: signature appended when no previous signature is found
  8. fallback: signature inserted above the quoted message on a reply
- Verified the suite fails on the broken code: 8 specs / 6 failures before the fix,
  8/8 after.
- No `Tests/Unit` (ObjC) addition: the change is pure client-side JS; the ObjC unit
  suite has no JS engine. The jasmine spec above is the unit test for this fix.
- The 5695 "regex too big" catch branch is intentionally unchanged (per ticket) and
  cannot be exercised on Node/V8, which does not throw on oversized patterns —
  that failure mode is WebKit/Safari-specific.

## Verification steps for the orchestrator

Unit suite (ran clean; only known host noise + pre-existing runner limitation):

```
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c8-6214
# Ran 67 tests — FAILED (2 failures, 2 errors)
#  - test_NGInternetSocketAddressFromString, test_stringWithoutHTMLInjection: known host noise (AGENTS.md)
#  - TestSOGoDraftObject setUp x2: "Mailer.SOGo bundle missing" — pre-existing; the
#    minimal runner builds SOPE + SOGo framework only, never SoObjects/Mailer
#    (the main checkout has the bundle built, worktrees don't). Unrelated to this JS-only change.
```

Signature spec (pure node, no stack):

```
cd /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c8-6214/Tests
/home/hadrienblanc/Projets/hadrienblanc/sogo/sogo/Tests/node_modules/.bin/jasmine \
  --config=spec/support/jasmine.json --filter="MessageEditorController signature handling"
# or, to avoid loading stack-dependent specs: see Tests/spec/MailerIdentitySignatureSpec.js
# → 8 specs, 0 failures
```

(In the e2e container the file is picked up automatically by the jasmine glob
`**/*[sS]pec.?(m)js`; no stack required.)

Manual UI check (needs a browser, optional): user with a personal identity whose
signature contains a URL, plus a shared mailbox identity without signature,
`SOGoMailComposeMessageType = text`: compose → switch From to the shared mailbox →
body becomes empty (signature and `-- ` marker removed); switch back → exactly one
signature. HTML mode: type in the body first (forces CKEditor normalization), then
switch → old signature replaced, no duplicate.

## PR body draft

> ### fix(mail): stop duplicating signatures when switching identity in compose (bug 6214)
>
> When switching the From address while composing, the previous signature was left
> in place and the new identity's signature was appended, duplicating both the
> `-- ` marker and the signature block. The regression came from the fix for
> #5695/#6168 (71d865b): it replaced the compose-mode-aware regexp used to locate
> the previous signature with a pattern hardcoding HTML markup (`--&nbsp;<br />`)
> regardless of the compose mode, and dropped the escaping of regex
> metacharacters, so plain-text drafts (`-- \n`) and signatures containing
> `. + ( ) / ?` (URLs, phone numbers) could never match. The signature is escaped
> again, the pattern is rebuilt from the mode-aware variables (`reNl`, `nlNb`,
> `space`), and the "regex too big" fallback for oversized signatures (#5695) is
> kept.
>
> AVANT (plain text, `SOGoMailComposeMessageType = text`, signature with a URL) :
> composer avec l'identité personnelle, basculer le From vers une boîte partagée
> puis revenir → le corps contient deux blocs `-- \n<signature>` ; le marqueur
> HTML codé en dur ne matche jamais `-- \n`. APRÈS : la signature précédente (et
> son marqueur) est localisée et remplacée/supprimée dans les deux modes ; en
> HTML, le motif tolère en plus la sérialisation CKEditor 5 (`<br>` sans slash,
> paragraphes `<p>` automatiques, `<br />` réécrit en `<br>` à l'intérieur de la
> signature), couvrant aussi le scénario #6168 après normalisation de l'éditeur.
> Un test jasmine unitaire (`MailerIdentitySignatureSpec.js`) instancie le vrai
> contrôleur et verrouille les 8 chemins (suppression, remplacement, placement
> haut/bas, HTML brut/normalisé, fallbacks) : 6 des 8 échouent sur le code cassé.
