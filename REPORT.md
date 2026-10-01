# Ticket 6186 — Attachments/content not displayed in the preview when forwarding

**Branch:** `fix-6186-mantis` — commit `311b71ed8`

## Root cause (file:line)

When forwarding inline in HTML compose mode, SOGo renders the quoted-message
header block through the `SOGoMailForward` component
(`SoObjects/Mailer/SOGoMailForward.m`), interpolated unescaped into the draft
HTML (`SOGoMailEnglishForward.wo/SOGoMailEnglishForward.html`, all bindings
`escapeHTML = NO`).

On SOGo 5.12.4 (reporter's version) **every** header value was inserted raw.
The ticket's DevTool.png shows the smoking gun: an Outlook/Exchange
`References` message-id
`<dudpr@imb11375a27a6d84913ed336c9e2eb74a@dudpr@imb11375.eurprddl.prod.gelabs.com>`
was inserted unescaped, so the HTML parser turned `<dudpr@...>` into a phantom
*element*. CKEditor 5 flags/renames it (`data-ck-unsafe-element="dudpr@..."`,
hidden with `display:none`) — the reporter's "CKEditor classifies the text as
unsafe content" — and everything after `Referenzen:` (the whole forwarded
body) becomes invisible in the editor.

- The `References`/`Organization`/`Newsgroups` instances of this bug were
  already fixed on `experimental` by f11f34cde (for #6046), at
  `SoObjects/Mailer/SOGoMailForward.m:156,208,225`.
- **The last unescaped field of the same template was `subject`**
  (`SoObjects/Mailer/SOGoMailForward.m:86-89`): a subject containing angle
  brackets (e.g. `WG: <Testinhalt>`) reproduces the exact same swallow.
  The fix escapes it in HTML composition mode. `SOGoMailReply` inherits the
  same accessor, so Outlook-style replies are covered too.

So: the ticket **is a real bug**; its main instance (References) was already
fixed on `experimental` but was never locked by tests, and the identical
subject path was still open. Both are addressed here.

## What changed (before/after)

`SoObjects/Mailer/SOGoMailForward.m` — `subject`:

```diff
 - (NSString *) subject
 {
-  return [sourceMail decodedSubject];
+  NSString *subject;
+
+  subject = [sourceMail decodedSubject];
+  if (htmlComposition)
+    subject = [subject stringByEscapingHTMLString];
+
+  return subject;
 }
```

`Tests/Unit/TestSOGoMailForward.m` (new) + registration in
`Tests/Unit/GNUmakefile`.

### AVANT (server, live stack, current experimental)

`GET .../folderINBOX/<uid>/forward` → draft `edit` text:

```
Subject: WG: <Testinhalt> 6186<br/>Date: ...<br/>References: &lt;dudpr@...&gt;<br/>...
```

The raw `<Testinhalt>` is parsed as an HTML tag by the editor.

### AVANT (client, SOGo's own CKEditor 5 build 44.1.0, jsdom harness)

Editing-view textContent stops right after the subject — everything else is
swallowed by the phantom element, exactly like DevTool.png:

```
"-------- Original Message --------Subject: WG: "
hidden spans: [ '<span data-ck-unsafe-element="testinhalt">' ]
```

### APRÈS

Draft text: `Subject: WG: &lt;Testinhalt&gt; 6186<br/>...`

CKEditor editing-view textContent — full content visible:

```
"-------- Original Message --------Subject: WG: <Testinhalt> 6186Date: ... References: <dudpr@...>Testinhalt 24.02.26Original message body text."
```

(The remaining `data-ck-unsafe-element="o:p"` spans are empty Outlook
`<o:p></o:p>` markers — harmless, no content loss.)

Note on the ticket summary ("Attachments are not displayed"): the received
mail displays fine (`Received Email.png`); the missing content/preview in the
compose window is entirely caused by the chevron-in-header injection above —
there is no separate attachment bug.

## Tests

`Tests/Unit/TestSOGoMailForward.m` — 9 tests, all green:

- `test_htmlCompositionEscapesSubject` / `test_textCompositionKeepsSubject` /
  `test_missingSubjectYieldsNoValue` — the fix (both branches + nil subject)
- `test_htmlCompositionEscapesReferences` / `test_textCompositionKeepsReferences`
  — locks the ticket's exact case (Exchange message-id, both compose modes)
- `test_htmlCompositionEscapesOrganization`,
  `test_htmlCompositionEscapesNewsgroups` — locks the rest of f11f34cde
- `test_htmlCompositionEscapesAddresses` /
  `test_textCompositionKeepsAddresses` — from/to/cc/reply-to escaping
  (string and array headers)

Verified the new tests bite: with the fix stashed,
`test_htmlCompositionEscapesSubject` fails
(`'WG: &lt;Testinhalt&gt; 6186' and 'WG: <Testinhalt> 6186' differs`).

## Verification steps for the orchestrator

Unit suite (builds the worktree, runs 96 tests):

```
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c11-6186
```

Expected: `FAILED (2 failures, 0 errors)` — only the two known host-noise
failures (`test_NGInternetSocketAddressFromString`,
`test_stringWithoutHTMLInjection`).

End-to-end repro on the e2e stack (after deploying this branch), artifacts
are prefixed test-6186-* and must be cleaned up:

```
# 1. send /tmp/opencode-style Outlook-style mail (chevrons in References + subject)
python3 - <<'EOF'
import smtplib
msg = open('/tmp/opencode/6186/test-6186-outlook.eml','rb').read()
s = smtplib.SMTP('127.0.0.1', 2500); s.sendmail('brwa.baban@bearingpoint.com', ['sogo-tests1@example.org'], msg); s.quit()
EOF

# 2. forward it inline and fetch the draft text (cookie auth + GETs)
python3 /tmp/opencode/6186/repro.py
#    APRES: raw <Testinhalt> tag present: False
#           escaped Testinhalt present: True
#           escaped msgid present: True   (References already escaped pre-fix)

# 3. cleanup
python3 /tmp/opencode/6186/cleanup.py
```

Client-side AVANT/APRES harness (jsdom + the repo's CKEditor build):

```
cd /tmp/opencode/6186 && npm install jsdom
node ckeditor-check.js        # AVANT: textContent ends at "Subject: WG: "
node ckeditor-check-fixed.js  # APRES: full body visible
```

## PR body draft

When an email forwarded from Outlook's Sent folder is forwarded again in
SOGo with HTML composition, the compose editor shows only the quoted header
lines and the message body disappears. CKEditor 5 logs the content as
"unsafe": the header block of the inline-forward template interpolated raw
header values into the draft HTML, and any angle bracket in them (typically
the `<message-id>` chevrons of the References header, or a subject like
`WG: <Testinhalt>`) is parsed as a phantom HTML element which CKEditor hides
and which swallows the rest of the forwarded content.

References, Organization and Newsgroups were already escaped on experimental
(#6046); this PR closes the last unescaped field of the same template — the
subject — and locks the whole header-block escaping behaviour with unit
tests (`Tests/Unit/TestSOGoMailForward.m`), since none of the previous
escaping had test coverage. Outlook-style replies, which reuse the same
accessors via `SOGoMailReply`, benefit from the fix as well.

AVANT: `Subject: WG: <Testinhalt> 6186` → the editor renders
`-------- Original Message --------Subject: WG: ` and nothing else
(`data-ck-unsafe-element="testinhalt"` in the DOM, cf. ticket DevTool.png).
APRES: the draft carries `Subject: WG: &lt;Testinhalt&gt; 6186` and the full
forwarded body — text and attachments — stays visible and editable in
CKEditor.
