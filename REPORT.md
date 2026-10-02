# Bug 6158 — Stored XSS via address book categories (`/Preferences#!/addressbooks`)

Branch: `fix-6158-mantis` — commit `d550d93ec`

## Verdict

The vulnerability **was real** and the fix referenced by the maintainer upstream
(`e9b3f2a43`, "prevent xss with events, tasks and contacts categories") is already
part of our lineage: it was folded into `47133fdf3` which added
`stringWithoutHTMLInjection:` pre-parse filtering to the contact/list/appointment/task
editor saves, and `a7023bce1` (2024) had already added the same to the Preferences
`saveAction`. With those commits, the payload from the ticket no longer executes:
the dangerous constructs are neutralized server-side and every client-side sink for
contact categories escapes by construction (Angular bound values: `{{$chip.value}}`,
`md-highlight-text` uses `.text()`, Preferences uses `ng-model` inputs; no raw-HTML
sink exists — `ng-bind-html` is only used for `$fullname`, which HTML-entitizes).

However, the layered fix has a demonstrable hole that leaves the exact "stored XSS"
class of this ticket open one regression away: **the filter runs on the raw request
string *before* `objectFromJSONString`**, so JSON `\uXXXX` escapes decode *after*
filtering and arbitrary markup still reaches storage. This commit closes that hole
for categories.

## Root cause (file:line)

- `UI/PreferencesUI/UIxPreferences.m:1753-1755` — `saveAction` filters the raw JSON
  text (`stringWithoutHTMLInjection: NO stripAngular: NO`) and only then calls
  `objectFromJSONString`; `defaults.SOGoContactsCategories` (and the calendar
  category keys) are persisted as-is via `[[[user userDefaults] source] setValues: v]`
  (line ~1993), bypassing `setContactsCategories:` entirely.
- `UI/Contacts/UIxContactEditor.m:488` — same order-of-operations issue: pre-parse
  filter, then decode, then `setAttributes:` stores `categories[].value` raw into the
  vCard (line 383). Stored card categories are later merged back into
  `SOGoContactsCategories` by `UIxContactView.m:102`.

Consequence: `{"defaults":{"SOGoContactsCategories":["\u003cscript\u003ealert(1)\u003c/script\u003e"]}}`
stores a literal `<script>alert(1)</script>` category, echoed back by
`Preferences/jsonDefaults` and offered in every category picker. Today's sinks
escape it; nothing guarantees the next one will.

Reproducer on the shared stack (was **down** during this session — connection
refused on 127.0.0.1:50001, and container restarts are orchestrator-only, so no
live run was possible; the sequence below is for the orchestrator after rebuild):

```bash
curl -s -u sogo-tests1:sogo http://127.0.0.1:50001/SOGo/so/sogo-tests1/Preferences/save \
     -H 'Content-Type: application/json' \
     -d '{"defaults":{"SOGoContactsCategories":["\u003cscript\u003ealert(1)\u003c/script\u003e"]}}'
curl -s -u sogo-tests1:sogo http://127.0.0.1:50001/SOGo/so/sogo-tests1/Preferences/jsonDefaults \
     | python3 -c 'import json,sys; print(json.load(sys.stdin)["SOGoContactsCategories"])'
```

## What changed

**Before** — category data was only filtered in its serialized form:

```objc
requestStr = [[context request] contentAsString];
requestStr = [requestStr stringWithoutHTMLInjection: NO stripAngular:NO];
o = [requestStr objectFromJSONString];            // \uXXXX decodes AFTER the filter
...
[[[user userDefaults] source] setValues: v];      // raw markup persisted
```

**After** — the three category containers are sanitized once parsed
(`YES stripAngular: NO`, the codebase's "plain label" treatment used for folder
names and identities):

- `UI/PreferencesUI/UIxPreferences.m` (`saveAction`, right after the defaults dict
  is made mutable): `SOGoContactsCategories` and `SOGoCalendarCategories` values go
  through the new `NSArray` helper; `SOGoCalendarCategoriesColors` is rebuilt with
  sanitized keys.
- `UI/Contacts/UIxContactEditor.m:383`: each `categories[].value` is sanitized
  before `[card setCategories:]`, closing the same bypass at the editor sink the
  upstream fix targeted.
- `SoObjects/SOGo/NSArray+Utilities.h/.m`: new
  `stringsWithoutHTMLInjection:stripAngular:` mapping NSString members through the
  existing NSString filter, leaving non-strings untouched.

Normal category names (`Ami`, `Client`, `R&D`, `fb <foo@bar.com>` — the email-ish
form is explicitly preserved by the filter) are unchanged; legitimate use is
unaffected.

## Tests

- New `Tests/Unit/TestNSArray+Utilities.m` (registered in `Tests/Unit/GNUmakefile`):
  - `test_stringsWithoutHTMLInjection` — plain names untouched; `<script>`,
    `<img … onerror=…>` stripped; email-form preserved.
  - `test_stringsWithoutHTMLInjectionKeepsNonStrings` — non-string members pass
    through (error-path/robustness).
  - `test_stringsWithoutHTMLInjectionAfterJSONDecoding` — reproduces the ticket's
    attack end-to-end at library level: the `\u003c` payload survives the raw
    pre-parse pass (documented), decodes to `<script>`, and the post-parse
    sanitization cleans it.
- Suite: `local/run-worktree-tests.sh` → 197 tests, only the two documented
  host-noise failures (`test_NGInternetSocketAddressFromString`,
  `test_stringWithoutHTMLInjection`). Both changed UI products compile
  (`UI/PreferencesUI`, `UI/Contacts` — bundle link fails only because sibling
  bundles aren't built in this fresh worktree).

Note: `config.make` was copied from the main checkout into the worktree (generated,
git-ignored build artifact required by the test runner).

## Verification steps for the orchestrator

After the stack is rebuilt with this branch merged:

```bash
# 1. stored category must come back sanitized (AVANT: ["<script>alert(1)</script>"])
curl -s -u sogo-tests1:sogo http://127.0.0.1:50001/SOGo/so/sogo-tests1/Preferences/save \
     -H 'Content-Type: application/json' \
     -d '{"defaults":{"SOGoContactsCategories":["\u003cscript\u003ealert(1)\u003c/script\u003e","test-6158-ami","\u003cimg src=x onerror=alert(1)\u003e"]}}'
curl -s -u sogo-tests1:sogo http://127.0.0.1:50001/SOGo/so/sogo-tests1/Preferences/jsonDefaults \
     | python3 -c 'import json,sys; print(json.load(sys.stdin)["SOGoContactsCategories"])'
# expected: [' alert(1) ', 'test-6158-ami', ' ']

# 2. card categories go through the same treatment
curl -s -u sogo-tests1:sogo http://127.0.0.1:50001/SOGo/so/sogo-tests1/Contacts/personal/new/save \
     -H 'Content-Type: application/json' \
     -d '{"id":"test-6158","pid":"personal","c_cn":"test-6158","categories":[{"value":"\u003cscript\u003epwn\u003c/script\u003e"}]}'

# 3. calendar colors keys
curl -s -u sogo-tests1:sogo http://127.0.0.1:50001/SOGo/so/sogo-tests1/Preferences/save \
     -H 'Content-Type: application/json' \
     -d '{"defaults":{"SOGoCalendarCategoriesColors":{"\u003cb\u003etest-6158":"#CCC"}}}}'
# then check jsonDefaults -> SOGoCalendarCategoriesColors keys

# 4. unit tests
local/run-worktree-tests.sh <worktree>   # 197 tests, 2 known host-noise failures

# 5. cleanup of test artifacts
curl -s -u sogo-tests1:sogo http://127.0.0.1:50001/SOGo/so/sogo-tests1/Preferences/save \
     -H 'Content-Type: application/json' \
     -d '{"defaults":{"SOGoContactsCategories":[]}}'
# (and delete the test-6158 card from the personal address book)
```

## PR body draft

**fix(security): sanitize category names after JSON decoding (bug 6158)**

Stored XSS was reported (bug 6158) against the address book categories configured
from `/Preferences#!/addressbooks`. The upstream hardening (`e9b3f2a43`, included
here via `47133fdf3`) filters the editors' save payloads, and the Preferences save
action had been filtering its raw body since `a7023bce1` — but all of it runs
*before* the JSON is decoded, so an attacker could post
`"\u003cscript\u003ealert(1)\u003c/script\u003e"` and have a literal `<script>` tag
decoded afterwards, stored in `SOGoContactsCategories` (or a card's categories,
which are later merged back into the user's category list), and echoed to every
module. Today's Angular sinks escape these values, so nothing executes — but the
stored payload is exactly the class of issue this ticket reports, and one
`ng-bind-html`-style regression away from firing.

AVANT: `POST /Preferences/save {"defaults":{"SOGoContactsCategories":["\u003cscript\u003ealert(1)\u003c/script\u003e"]}}`
→ `jsonDefaults` returns `["<script>alert(1)</script>"]`.
APRÈS: the same request returns `[" alert(1) "]` — tags removed after decoding,
plain names (`Ami`, `R&D`, `fb <foo@bar.com>`) untouched.

This PR sanitizes the category containers once parsed — `SOGoContactsCategories`,
`SOGoCalendarCategories`, the `SOGoCalendarCategoriesColors` keys in the
Preferences save action, and each `categories[].value` in the contact editor —
using the existing `stringWithoutHTMLInjection` filter via a new
`NSArray stringsWithoutHTMLInjection:stripAngular:` helper, with unit tests
covering the `\uXXXX` bypass end-to-end plus the non-string edge cases.
