# Bug 6182 — Save button disabled on Mail settings page

https://bugs.sogo.nu/view.php?id=6182 — severity major, [ SOGo ] Web Preferences,
reproducible always, reported on 5.12.5 (@56d874c68700).

## Root cause (file:line)

- `UI/WebServerResources/js/Preferences/Preferences.service.js:237` — the
  `$mdDateLocaleProvider.isDateComplete` override installed by the Preferences
  service uses:

  ```js
  var re = /^((([a-zA-Z]|[^\x00-\x7F]){2,}|[0-9]{1,4})([ .,]+|[/-])){2}(([a-zA-Z]|[^\x00-\x7F]){3,}|[0-9]{1,4})$/;
  ```

  The pattern is anchored on a **final month name or number**: a short date
  string that ends with a dot can never match.

Chain of events (verified against the shipped sources):

1. The Mail settings tab renders two `md-datepicker` inputs for the vacation
   auto-reply window (`UI/Templates/PreferencesUI/UIxPreferences.wox:1246` and
   `:1267`). They format their value with the user's `SOGoShortDateFormat`
   through `$mdDateLocaleProvider.formatDate`.
2. For locales whose short date format ends with a dot — Hungarian
   `%Y.%b.%d.` (the reporter's case: `2026.Már.23.`), Montenegrin
   `%e.%m.%y.` shipped in `UI/MainUI/Montenegrin.lproj/Locale:23` (`23.03.26.`) —
   the formatted string ends with `.`.
3. Angular Material's `DatePickerCtrl.isInputValid`
   (`angular-material.js:17806`) requires `locale.isDateComplete(input)`;
   the regex rejects the trailing dot, so `updateErrorState` sets the
   ngModel `valid` flag to false.
4. The datepickers live inside `preferencesForm`
   (`UIxPreferences.wox:31`), so the form becomes `$invalid` and the save
   FAB (`UIxPreferences.wox:83-87`,
   `ng-disabled="preferencesForm.$invalid || preferencesForm.$pristine"`)
   stays disabled for the **entire tab**, even where dates are irrelevant —
   exactly what the reporter describes.

Note: `String.prototype.parseDate` (`Common/utils.js:181`) already tolerates
the trailing dot (leftover input is ignored), and `Date.prototype.format`
produces it faithfully — only `isDateComplete` blocked the save. The ticket
**is a real bug**; the regex is the right place to fix it (the trailing dot is
legitimate typography in these locales, not invalid input).

## What changed (before/after)

`UI/WebServerResources/js/Preferences/Preferences.service.js:237` (and the
generated bundle `UI/WebServerResources/js/Preferences.services.js`, same
literal, per repo convention for JS fixes):

```diff
-        var re = /^((([a-zA-Z]|[^\x00-\x7F]){2,}|[0-9]{1,4})([ .,]+|[/-])){2}(([a-zA-Z]|[^\x00-\x7F]){3,}|[0-9]{1,4})$/;
+        var re = /^((([a-zA-Z]|[^\x00-\x7F]){2,}|[0-9]{1,4})([ .,]+|[/-])){2}(([a-zA-Z]|[^\x00-\x7F]){3,}|[0-9]{1,4})\.?$/;
```

One optional trailing dot is now accepted after the final component.

- AVANT: `isDateComplete("2026.Már.23.")` → `false` → `preferencesForm.$invalid`
  → save button disabled on the whole Mail settings tab.
- APRÈS: `isDateComplete("2026.Már.23.")` → `true`; the model stays valid and
  the save button enables as soon as something is edited.

Guards preserved (covered by tests): partially typed dates (`23.03`,
`2026.márc`) are still incomplete, and a double trailing dot (`23.03.26..`)
is still rejected. No server-side (Obj-C) code involved.

## Tests

- New `Tests/spec/PreferencesIsDateCompleteSpec.js` (jasmine, same
  source-loading pattern as `SchedulerComponentControllerSpec.js`; no stack
  required). It loads the real `Preferences.service.js` with stubbed Angular
  and drives the actual `$mdDateLocaleProvider` adapter installed by the
  service constructor:
  - formats a Hungarian `%Y.%b.%d.` date (`2026.márc.23.`) and asserts
    `isDateComplete` accepts it;
  - same for the Montenegrin `%e.%m.%y.` shipped format (`23.03.26.`);
  - round-trips `parseDate('2026.márc.23.')` to 2026-03-23;
  - dot-free formats (`23-Mar-26`, `3/14/16`, `23.03.26`) still complete;
  - partial input (`23.03`, `2026.márc`) and `23.03.26..` still incomplete.
  - Verified the spec **fails on the pre-fix source** (2 failures) and passes
    after the fix.
- No `Tests/Unit` (Obj-C) test added: the change is entirely client-side JS;
  there is no server code path to cover (per AGENTS.md the JS spec is the
  unit test; e2e re-verification happens at the orchestrator's stack rebuild).
- `local/run-worktree-tests.sh wt/c11-6182`: 99 tests, only the 2 documented
  host-noise failures (`test_NGInternetSocketAddressFromString`,
  `test_stringWithoutHTMLInjection`).

## Verification steps for the orchestrator

1. JS spec (in the `sogo_dev` container, as usual):
   `cd /workspace/Tests && sed -i 's/port: "50001"/port: "50000"/' lib/config.js && npx jasmine --filter='Preferences date locale (bug 6182)'` —
   expect 5 specs, 0 failures (restore `lib/config.js` afterwards).
   Local pre-merge equivalent used here:
   `node ../sogo/Tests/node_modules/jasmine/bin/jasmine.js --config=/tmp/opencode/jasmine-6182.json`
   from `wt/c11-6182/Tests` (minimal config without the `esm` require, which
   is incompatible with the host's Node 25).
2. Regex sanity (host, read-only):
   ```bash
   node -e 'var re=/^((([a-zA-Z]|[^\x00-\x7F]){2,}|[0-9]{1,4})([ .,]+|[/-])){2}(([a-zA-Z]|[^\x00-\x7F]){3,}|[0-9]{1,4})\.?$/;
     console.log(["2026.Már.23.","23.03.26.","23.03.26","23.03"].map(function(s){return s+": "+re.test(s)}).join("\n"))'
   # expected: true, true, true, false
   ```
3. Obj-C unit suite: `local/run-worktree-tests.sh ~/Projets/hadrienblanc/sogo/wt/c11-6182`
   — 99 tests, 2 known host-noise failures only. (First run in this worktree
   needed `source local/env.sh && ./configure --enable-debug --disable-strip`
   to generate the git-ignored `config.make`.)
4. Manual e2e after stack rebuild (browser): set a Hungarian short date format
   (`%Y.%b.%d.`) on the General preferences tab, then open Mail settings —
   the vacation datepickers show `2026.márc.23.`-style values and the save
   button must enable when something is modified.

Stack note: static assets under `/SOGo.woa/WebServerResources/` answer 404 on
the shared stack from the host, so the bundle could not be re-fetched over
HTTP for a before/after diff; the reproduction was done against the exact
shipped sources in-tree (regex extracted verbatim from
`Preferences.services.js`).

## PR body draft

The Mail settings tab could never be saved with a short date format that ends
with a dot. The `isDateComplete` override installed on Angular Material's date
locale required the date string to end with a month name or a number, so the
vacation date pickers — which format their value with the user's
`SOGoShortDateFormat` — marked their model invalid for locales such as
Hungarian (`%Y.%b.%d.` → `2026.Már.23.`) or the shipped Montenegrin format
(`%e.%m.%y.` → `23.03.26.`). Because both pickers sit inside
`preferencesForm`, the whole form turned `$invalid` and the save button
stayed disabled for the entire tab, even on sections where the dates play no
role. Parsing was never the problem: `String.prototype.parseDate` already
ignored the trailing dot.

AVANT: with `SOGoShortDateFormat = "%Y.%b.%d."`, the picker shows
`2026.Már.23.`, `isDateComplete` returns false, the model is flagged invalid
and the save FAB of Mail settings never enables.

APRÈS: an optional trailing dot is accepted by the completeness check; the
model stays valid, the save button enables as soon as anything is edited.
Partially typed dates (`23.03`, `2026.márc`) and doubled trailing dots
(`23.03.26..`) are still rejected, so the picker keeps flagging genuinely
incomplete input. Covered by the new offline jasmine spec
`Tests/spec/PreferencesIsDateCompleteSpec.js` (5 cases, red before / green
after).
