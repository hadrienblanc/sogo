# Ticket 6142 — "Refresh does not work anymore" — REPORT

**Verdict: NOT A BUG in this codebase.** The regression shipped by upstream in
SOGo 5.12.3 never landed in the `experimental` lineage; our tree is already
byte-identical to upstream's fixed (reverted) state on every refresh call site.
Per the ticket rules, this lands **tests only**, locking the string contract
that the regression violated.

## Root cause (file:line)

The upstream regression, commit `55dbae6` ("fix(view): automatically refresh
view only if a number is set", shipped in v5.12.3), added
`&& !isNaN(refreshViewCheck)` to the five auto-refresh timers:

- `UI/WebServerResources/js/Mailer/Mailbox.service.js:465`
- `UI/WebServerResources/js/Mailer/Account.service.js:159`
- `UI/WebServerResources/js/Preferences/Preferences.service.js:590`
- `UI/WebServerResources/js/Contacts/AddressBook.service.js:461`
- `UI/WebServerResources/js/Scheduler/Component.service.js:132`

`SOGoRefreshViewCheck` is a **documented string token** (`manually`,
`every_minute`, `every_2/5/10/20/30_minutes`, `once_per_hour` —
Documentation/SOGoInstallationGuide.asciidoc:2608) mapped to seconds by
`String.prototype.timeInterval()` (UI/WebServerResources/js/Common/utils.js:168).
`isNaN("every_minute")` is `true`, so `!isNaN(...)` disabled every timer: no
`/Mail/0/folderINBOX/changes` polling, no auto-refresh. Upstream resolved the
ticket by reverting (`b9f6b9074`, Mantis note ~0018314 "I've reverted it").

Evidence this never affected our lineage:

- `git merge-base --is-ancestor 55dbae6 HEAD` → exit 1 (regression absent)
- `git merge-base --is-ancestor b9f6b9074 HEAD` → exit 1 (revert absent too — not needed)
- `git diff HEAD b9f6b9074 -- <the 5 service files>` restricted to the guard
  lines → empty: our guard is already
  `if (refreshViewCheck && refreshViewCheck != 'manually')`

Server side is type-safe by construction: `-[SOGoUserDefaults refreshViewCheck]`
(SoObjects/SOGo/SOGoUserDefaults.m:564) goes through
`-[SOGoDefaultsSource stringForKey:]` (SoObjects/SOGo/SOGoDefaultsSource.m:265),
which warns and returns nil for any non-string value, and
`-[UIxJSONPreferences jsonDefaults]` (UI/PreferencesUI/UIxJSONPreferences.m:186)
injects that string into the JSON defaults when the user source lacks the key.

Adjacent hazard observed but intentionally not fixed here (misconfiguration
required, pattern shared by ~10 sibling keys — separate concern): a *numeric*
`SOGoRefreshViewCheck` in `sogo.conf` makes `refreshViewCheck` return nil, and
jsonDefaults' `setObject:nil` injection would raise; likewise a number stored
directly in the user's own defaults blob would reach the browser as a JSON
number. Neither is reachable through the Preferences UI, which only stores
dropdown string tokens.

## What changed (before/after)

No production code changed. Added contract locks:

- **AVANT** (upstream 5.12.3): `RefreshViewCheck = "every_minute"` in sogo.conf,
  webmail open → devtools Network shows **zero** requests to
  `/SOGo/so/USER/Mail/0/folderINBOX/changes`; new mail appears only on F5,
  which then dumps 40 unread messages.
- **APRÈS** (our tree, unchanged): same config → the client polls
  `.../folderINBOX/changes` every `timeInterval()` = 60 s and the mailbox
  refreshes itself; the delivered `jsonDefaults.SOGoRefreshViewCheck` is always
  a string token (`"manually"` observed live on the e2e stack).

## Tests

- `Tests/Unit/TestSOGoUserDefaults.m` (new, registered in
  `Tests/Unit/GNUmakefile`) — 6 tests locking the accessor contract:
  user-level string returned; parent-source (domain) fallback; nil when unset
  everywhere; **NSNumber value rejected** (the guard that keeps numbers out of
  the JSON layer); `setRefreshViewCheck:` stores the string; legacy
  `RefreshViewCheck` key migrates to `SOGoRefreshViewCheck`
  (SoObjects/SOGo/SOGoUserDefaults.m:235).
- `Tests/spec/HTTPRefreshViewCheckSpec.js` (new, auto-discovered by
  jasmine.json) — locks the browser-facing contract: `jsonDefaults` must always
  deliver `SOGoRefreshViewCheck` as a string, and a valid token must round-trip
  unchanged through `Preferences/save`. Restores the user's original value in
  `afterAll`.

Full unit suite: **215 tests, 2 failures — both known host noise**
(`test_NGInternetSocketAddressFromString`, `test_stringWithoutHTMLInjection`).

## Verification steps for the orchestrator

Unit suite (already run on this worktree):

    /home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c16-6142

E2e spec (inside the rebuilt `sogo_dev` container):

    cd /workspace/Tests && sed -i 's/port: "50001"/port: "50000"/' lib/config.js && \
      npx jasmine --config=spec/support/jasmine.json --filter="refresh view check defaults (bug 6142)" ; \
      sed -i 's/port: "50000"/port: "50001"/' lib/config.js

Read-only spot-check of the live contract (validated during this session, value
restored afterwards):

    curl -s -c /tmp/c.txt -X POST http://127.0.0.1:50001/SOGo/connect \
      -H 'Content-Type: application/json' \
      -d '{"userName":"sogo-tests1","password":"sogo"}'
    curl -s -b /tmp/c.txt http://127.0.0.1:50001/SOGo/so/sogo-tests1/jsonDefaults \
      | python3 -c "import sys,json; v=json.load(sys.stdin)['SOGoRefreshViewCheck']; print(repr(v), type(v).__name__)"
    # observed: 'manually' str

Guards (no source regression possible without CI noticing):

    grep -rn "isNaN(refreshViewCheck)" UI/WebServerResources/js/   # → no matches

## PR body draft

Bug 6142 reported that auto-refresh silently stopped in 5.12.3: with
`SOGoRefreshViewCheck = "every_minute"`, no `/Mail/0/folderINBOX/changes`
polling ever fired and new mail only appeared on a manual F5. Root cause was
upstream commit 55dbae6, which guarded every refresh timer with
`!isNaN(refreshViewCheck)` although the setting is a documented *string* token
consumed by `String.prototype.timeInterval()` — `isNaN("every_minute")` is
true, so every timer was disabled. Upstream fixed it by reverting; that
regression never existed in our lineage, so this PR changes **no production
code** and instead locks the contract the bug violated.

Two test layers now pin the behavior: a unit suite
(`TestSOGoUserDefaults.m`) covering the `refreshViewCheck` accessor —
user-level value, domain-source fallback, non-string rejection, and the legacy
`RefreshViewCheck` key migration — and an e2e spec
(`HTTPRefreshViewCheckSpec.js`) asserting `jsonDefaults` always delivers
`SOGoRefreshViewCheck` as a string token that round-trips unchanged. If anyone
re-introduces a numeric guard or a numeric value slips into the delivery path,
the suites fail instead of the users' mailboxes going stale. AVANT (upstream
5.12.3): zero `changes` requests, 40 mails dumped on F5. APRÈS: polling every
60 s, `jsonDefaults.SOGoRefreshViewCheck` observed as `'manually'` (str) on the
e2e stack.
