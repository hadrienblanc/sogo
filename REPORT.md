# Bug 6180 — HTML emails from Outlook/Word render incorrectly in SOGo webmail (mso-* CSS)

https://bugs.sogo.nu/view.php?id=6180 — severity minor, [ SOGo ] GUI,
reproducible always, reported on 5.12.4 (@ega, confirmed by Bahnkonzept).

Verdict: **real bug** — reproduced live on the shared e2e stack, root-caused
to two defects in SOGo's mail HTML pipeline (not to "mso-* properties being
ignored": unknown CSS properties are correctly passed through and ignored by
the browser, exactly like in Thunderbird; the damage happens around them).

## Root cause (file:line)

Reproduced by PUTting realistic Outlook/Word `.eml` files into
`/SOGo/dav/sogo-tests1/Mail/0/foldertest-6180/` (DAV) and fetching
`/SOGo/so/sogo-tests1/Mail/0/foldertest-6180/<uid>/view` (the exact
endpoint the AngularJS webmail uses for the message body).

**Defect 1 — Office `<o:p>` paragraph marks become real paragraphs.**
The stack's libxml2 HTML parser strips namespace prefixes of unknown
elements (`o:p` → `p`, `w:sdt` → `sdt`, `v:rect` → `rect`, … — verified live).
All of these are harmless *except* `o:p`, whose local name collides with the
HTML `<p>` block element: every `<o:p>&nbsp;</o:p>` spacer Word emits between
paragraphs is rendered as a **nested real `<p>`** with browser-default
margins (~1em top+bottom), on top of a `p.MsoNormal` whose own rule sets
`margin:0cm`. Live before-state:

```
<p class="MsoNormal">Hello from Word, first paragraph.</p>
<p class="MsoNormal"><p>&#160;</p></p>        ← nested fake paragraph
```

Thunderbird treats `o:p` as an unknown inline element (no box, no margin),
which is why the same mail looks fine there. Owned by the pre-parsing pass
`-[NSData sanitizedContentUsingVoidTags:]`, called by
`UI/MailPartViewers/UIxMailPartHTMLViewer.m` (`_parseContent`) for both
`UIxMailPartHTMLViewer` and `UIxMailPartExternalHTMLViewer`.

**Defect 2 — brace-less CSS at-rules swallow the next rule.**
In `_appendStyle:` (the `<style>` sanitizer, formerly
`UI/MailPartViewers/UIxMailPartHTMLViewer.m:468`, now in
`UI/MailPartViewers/UIxHTMLMailContentHandler.m:435`), an `@` sets
`hasEmbeddedCSS = YES` and the flag is only cleared by a `}` at nesting
level 0. For a statement at-rule with no block — `@import url(...);`,
`@charset "utf-8";` — the `;` is not handled, so the parser treats the
**next rule's braces** as the at-rule's block and silently drops the whole
rule. Live before-state (mail whose CSS begins with `@import` for web
fonts, then Word's rules):

```
<style type="text/css">
  ← empty: p.MsoNormal {margin:0cm; ...} was swallowed
</style>
```

Every `<p>` then renders with browser-default margins → the "excessive
whitespace / broken layout" of the ticket. If a `@font-face` (braced at-rule)
sits between, it absorbs the swallow — which is why some Word mails render
acceptably and mails with `@import`-led CSS are "always" broken.

**About "message body appears completely blank":** not reproduced with any
realistic Outlook/Word structure (conditional comments, downlevel-revealed
`<!--[if !mso]><!-->`, VML style blocks, `w:WordDocument` islands all behave).
Most plausible extreme of defect 2: a mail whose *entire* layout CSS sits in
the single rule following a brace-less at-rule. Nothing suggests a third
defect; no fix was speculative-added for it.

## What changed (before/after)

1. `SoObjects/Mailer/NSData+Mail.m` (`sanitizedContentUsingVoidTags:`,
   new pass before the void-tag repair): removes `<o:p>`/`</o:p>` tags
   (case-insensitive; open tags with attributes and `<o:p…>` up to the next
   `>` included; a truncated tag without `>` is left untouched). Only the
   tags are removed — the spacer *content* (`&nbsp;`) stays inline, matching
   Thunderbird. Other prefixed elements (`w:`, `v:`, `st1:`, `m:`) are left
   alone: their prefix-stripped local names are unknown inline elements that
   carry no margins.

   - AVANT: `<p class=MsoNormal><o:p>&nbsp;</o:p></p>` →
     `<p class="MsoNormal"><p>&#160;</p></p>` (nested paragraph, ~2 extra em
     of blank space per spacer, of which Word emits one per blank line).
   - APRÈS: → `<p class="MsoNormal">&#160;</p>` (inline spacer, one line).

2. `UI/MailPartViewers/UIxHTMLMailContentHandler.m:435` (`_appendStyle:`,
   phase 2): a `;` while `hasEmbeddedCSS && embeddedCSSLevel == 0` now ends
   the at-rule statement (`hasEmbeddedCSS = NO`, cursor rebased), per CSS
   grammar (at-rules end at `;` **or** at their block). `;` inside
   `@font-face`/`@media` blocks (level ≥ 1) is untouched, and `@media` inner
   rules stay dropped by design (Gmail behaves the same — matches the
   reporter's "other webmails also show some degradation").

   - AVANT: `@import url("…");p.MsoNormal {margin:0cm;}` → empty CSS.
   - APRÈS: → `.SOGoHTMLMail-CSS-Delimiter p.MsoNormal {margin:0cm
     !important;}` (and `@import` does not leak into the CSS).

3. `UI/MailPartViewers/UIxHTMLMailContentHandler.{h,m}` (new): pure move of
   the private `_UIxHTMLMailContentHandler` SAX class out of
   `UIxMailPartHTMLViewer.m` (no behavior change; the viewer keeps
   `_xmlCharsetForCharset`, `_sanitizeHtmlForDisplay` and both viewer
   classes; `VoidTags` is exposed via `+voidTags` used by the viewer's 4
   `sanitizedContentUsingVoidTags:` call sites). Rationale: the class has no
   UI/superclass dependencies, and the move makes the sanitizer permanently
   unit-testable (AGENTS coverage rule) — `_appendStyle` had zero coverage.

Also: `UI/MailPartViewers/GNUmakefile` (compile the new file in the
MailPartViewers bundle), `Tests/Unit/GNUmakefile` (register the two test
files, compile the handler into the tool, xml2 cflags), `.gitignore`
(build-artifact dir created by compiling the UI source into the test tool).

## Tests

- New `Tests/Unit/TestNSData+Mail.m` (9 tests): `<o:p>`/`</o:p>` stripping
  (basic, close-tag, case+attributes, empty pair), guards (`<w:>`/`<v:>`/
  `<st1:>` untouched, `<p>`/`<pre>` untouched, truncated `<o:p` untouched)
  and regression locks for the adjacent pre-existing passes (meta charset
  stripping, `</br>` repair) which had no coverage.
- New `Tests/Unit/TestUIxHTMLMailContentHandler.m` (17 tests) driving the
  real handler with SAX events: the fix (rule kept after `@import;`/`@charset;`,
  at-rule text not leaked) and its guard rails (`;` inside `@font-face`/`@media`
  blocks is not a terminator, `@media` inner rules stay dropped, `@page` of
  Word mails), plus surrounding `_appendStyle`/`startElement` behavior now
  under coverage: mso properties passthrough, selector prefixing of
  `p.MsoNormal, li.MsoNormal, div.MsoNormal`, no `!important` duplication,
  `body` selector rewrite, `<!--`/`/* */` stripping in `<style>`, banned tags,
  `on*`/`unsafe-style`/`unsafe-src`/cid: attribute handling, body escaping,
  self-closed void tags.
- New `Tests/spec/MailHtmlRenderingSpec.js` (e2e, stack needed): PUTs a
  Word email (`@import`-led CSS + `<o:p>` spacers) via DAV, fetches `/view`,
  asserts both fixes end-to-end, cleans up its mailbox. Verified **red on the
  current (pre-fix) stack** with the same HTTP calls from the host (4 failing
  assertions: rule kept after @import, margin reset, mso property, no fake
  paragraph); turns green after deploy.
- Red/green discipline for the unit tests: with fix 2 reverted, exactly
  `test_atRuleStatementDoesNotSwallowNextRule` + `test_charsetAtRuleDoesNotSwallowNextRule`
  fail; with fix 1 reverted, exactly the 4 `OfficeParagraphMark` tests fail.
- `local/run-worktree-tests.sh wt/c11-6180`: **126 tests, only the 2
  documented host-noise failures** (`test_NGInternetSocketAddressFromString`,
  `test_stringWithoutHTMLInjection`). Baseline before the change: 99 tests,
  same 2 failures.

## Verification steps for the orchestrator

1. Unit suite (worktree):
   `local/run-worktree-tests.sh ~/Projets/hadrienblanc/sogo/wt/c11-6180`
   — expect 126 tests, 2 known host-noise failures only.
2. e2e jasmine (inside the `sogo_dev` container, after the cycle rebuild):
   `cd /workspace/Tests && sed -i 's/port: "50001"/port: "50000"/' lib/config.js && npx jasmine --filter='Mail HTML rendering (bug 6180)'`
   — expect 2 specs, 0 failures (restore `lib/config.js` afterwards).
3. Manual before/after on the stack (host, read-only):
   ```bash
   node /tmp/opencode/check6180.mjs   # same flow as the spec: MKCOL + PUT + /view + DELETE
   ```
   Expected after deploy: 8/8 `PASS` lines, exit 0 (currently on the pre-fix
   stack: 4 `FAIL` — rule kept after @import, margin reset kept, mso property
   kept, no fake paragraph from o:p). The script prints the rendered body:
   after deploy the spacer line must read `<p class="MsoNormal">&#160;</p>`
   (no nested `<p>`), and the `<style>` block must contain
   `.SOGoHTMLMail-CSS-Delimiter p.MsoNormal … margin:0cm !important`.
4. Reproduction artifacts `test-6180*` were removed from `sogo-tests1`
   (mailbox listing verified clean); the spec creates/deletes its own
   `test-6180-rendering` mailbox.

## PR body draft

HTML emails composed in Outlook/Word rendered with excessive whitespace and
broken spacing in SOGo webmail, while Thunderbird displays them fine. Two
defects in the mail HTML pipeline cause it — both reproduced live on the e2e
stack with realistic Word-generated emails. First, libxml2 strips the
namespace prefix of Office markup, so Word's `<o:p>&nbsp;</o:p>` paragraph-mark
spacers become *real* `<p>` elements with browser-default margins, nested
inside the very paragraphs whose CSS sets `margin:0cm`; the pre-parsing
sanitizer now removes the `o:p` tags (keeping their content inline, like
Thunderbird). Second, the `<style>` sanitizer treated `@import url(...);`-style
at-rule statements as block at-rules, so it silently swallowed the entire CSS
rule that followed — typically `p.MsoNormal {margin:0cm}` — leaving every
paragraph with default margins; a `;` at nesting level 0 now terminates the
statement, per CSS grammar. mso-* properties themselves were never the
culprit: they are passed through (with `!important`) and ignored by the
browser, exactly as in other clients.

AVANT: a Word mail with `@import`-led CSS renders with an empty `<style>`
block — every paragraph gets ~1em top/bottom margins — and each
`<o:p>&nbsp;</o:p>` spacer adds a nested blank paragraph (`<p class="MsoNormal"><p>&#160;</p></p>`),
blowing up the vertical spacing (ticket screenshot).

APRÈS: the `p.MsoNormal {margin:0cm !important}` rule survives after the
`@import` statement, `@font-face`/`@page` blocks stay dropped as before, and
spacers render inline (`<p class="MsoNormal">&#160;</p>`); Word/Outlook mails
keep their intended compact layout, matching Thunderbird. The private SAX
handler was moved to `UIxHTMLMailContentHandler.{h,m}` (pure move) so the
sanitizer is covered by 26 new unit tests plus an e2e spec verified red
before the fix.
