# Fix report — Mantis 6235: Vacation message: one day difference with sieve script

Branch: `fix-6235-mantis` (commit `f5c7be6de`), based on `experimental`.

## Root cause (file:line)

- `SoObjects/SOGo/SOGoSieveManager.m:1075-1089` (pre-fix lines; the vacation block
  of `-updateFiltersForAccount:withUsername:andPassword:forceActivation:`).

The web preferences store the vacation `startDate`/`endDate` values as epoch
seconds at **local midnight in the user's timezone** (the AngularJS UI sends
`Date.getTime()/1000` of the picked date — see
`UI/WebServerResources/js/Preferences/Preferences.service.js:834-847`).

The sieve generator then converted them back to a calendar date with:

```objc
startDate = [NSCalendarDate dateWithTimeIntervalSince1970: [epoch intValue]];
[startDate descriptionWithCalendarFormat: @"%Y-%m-%d"]
```

`dateWithTimeIntervalSince1970:` attaches the **sogod process-local timezone**
(`/etc/localtime` of the host running sogod — verified empirically: GNUstep
even ignores the `TZ` env var for this). Whenever the sogod host timezone
differs from the user's SOGo timezone, the date written into
`currentdate :value "ge"/"le" "date" "..."` is shifted by one day — exactly
what the reporter observed, and consistent with his resolution ("SOGo and IMAP
server timezones were different; after correcting that the bug disappeared").

Two in-tree consumers already treat the **user's** timezone as authoritative
for these very epochs, proving the intent:

- the same method uses `[[ud timeZone] secondsFromGMT]` for the `:zone`
  argument of the start/end **time** conditions (SOGoSieveManager.m:1092-1111
  pre-fix);
- `Tools/SOGoToolUpdateAutoReply.m:105-107` loads `SOGoTimeZone` from the
  user's defaults and calls `setTimeZone:` before computing vacation day
  boundaries.

## What changed (before/after)

AVANT — the date is formatted in the sogod process timezone:

```objc
startDate = [NSCalendarDate dateWithTimeIntervalSince1970:
                                [[values objectForKey: @"startDate"] intValue]];
[allConditions addObject: [NSString stringWithFormat: @"currentdate :value \"ge\" \"date\" \"%@\"",
                           [startDate descriptionWithCalendarFormat: @"%Y-%m-%d"]]];
```

Example: user timezone Europe/Paris, sogod host at UTC. The UI selection
"04/08/2026" is stored as epoch 1785801600 (2026-08-04 00:00 Paris =
2026-08-03 22:00 UTC); the script gets `currentdate :value "ge" "date"
"2026-08-03"` — one day off. With a host timezone east of the user's (e.g.
sogo in Pacific/Kiritimati, +14), an evening timestamp flips to
"2026-08-05" — the day-after reported in the ticket.

APRES — the date is formatted in the user's SOGo timezone, matching the
existing `:zone` handling of the time conditions:

```objc
+ (NSString *) sieveDateFromEpoch: (int) epoch
                         timeZone: (NSTimeZone *) timeZone
{
  NSCalendarDate *date;

  date = [NSCalendarDate dateWithTimeIntervalSince1970: epoch];
  [date setTimeZone: timeZone];

  return [date descriptionWithCalendarFormat: @"%Y-%m-%d"];
}
...
[allConditions addObject: [NSString stringWithFormat: @"currentdate :value \"ge\" \"date\" \"%@\"",
                           [SOGoSieveManager sieveDateFromEpoch:
                                           [[values objectForKey: @"startDate"] intValue]
                                                      timeZone: [ud timeZone]]]];
```

Same epoch 1785801600 now yields `currentdate :value "ge" "date" "2026-08-04"`
— identical to what the user picked, regardless of the sogod host timezone.
`[ud timeZone]` resolves through the defaults chain (user value, else domain
default `SOGoTimeZone = "UTC"` in `SoObjects/SOGo/SOGoDefaults.plist:95`);
if it were nil, GNUstep's `setTimeZone:` is a no-op, i.e. the previous
behavior — no regression path.

Files touched:

- `SoObjects/SOGo/SOGoSieveManager.h` — declare `+sieveDateFromEpoch:timeZone:`.
- `SoObjects/SOGo/SOGoSieveManager.m` — add the helper (next to
  `+sieveFlagForArgument:mailLabels:`), use it for both the start-date and
  end-date `currentdate` conditions; the now-unused `startDate`/`endDate`
  locals are gone.
- `Tests/Unit/TestSOGoSieveManager.m` — new test (file already registered in
  `Tests/Unit/GNUmakefile`).

The ticket is a real bug (not invalid): the code was provably inconsistent
about which timezone defines the vacation day. Note the reporter's own
workaround (aligning server timezones) still stands as valid ops practice,
because the generated `currentdate` tests carry no `:zone` and are therefore
evaluated in the sieve engine's local timezone; making the script fully
zone-explicit would change the generated-script format (and the e2e
`Tests/spec/SieveSpec.js` expectations) and was deliberately left out of this
minimal fix.

## Tests

`Tests/Unit/TestSOGoSieveManager.m` — `test_sieveDateFromEpoch_userTimeZone`:

- epoch 1785801600 (2026-08-04 00:00 Europe/Paris):
  Europe/Paris → `2026-08-04` (UI selection preserved),
  Asia/Tokyo → `2026-08-04`,
  America/New_York → `2026-08-03` (the one-day shift when the wrong zone is used);
- epoch 1785873600 (2026-08-04 20:00 UTC):
  Pacific/Kiritimati → `2026-08-05` (forward shift),
  Europe/Paris → `2026-08-04`.

The assertions are host-independent (explicit IANA zones, August dates with
unambiguous DST rules).

## Verification steps for the orchestrator

```bash
# build (SOPE objs + SOGo.framework + unit suite) and run the 271 unit tests
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
  /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c36-6235
# expect: "Ran 271 tests" / "OK"

# confirm the new test is part of the run and passes (0 failures)
cd /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c36-6235/Tests/Unit
source /home/hadrienblanc/Projets/hadrienblanc/sogo/local/env.sh
export LD_LIBRARY_PATH="/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c36-6235/SOPE/NGCards/obj:/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c36-6235/SOPE/GDLContentStore/obj:/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c36-6235/SoObjects/SOGo/SOGo.framework/Versions/Current/sogo:$LD_LIBRARY_PATH"
./obj/sogo-tests -f junit 2>/dev/null | grep -E 'testsuite name|test_sieveDateFromEpoch'
# expect: tests="271" errors="0" failures="0" and one <testcase name="test_sieveDateFromEpoch_userTimeZone">

# inspect the change
git -C /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c36-6235 show f5c7be6de
```

No artifacts were created on the shared stack (nothing to clean); no docker
commands, restarts or deploys were performed. Known host-noise failures
(test_NGInternetSocketAddressFromString, test_stringWithoutHTMLInjection) did
not occur in this run.

## PR body draft

**fix(sieve): format vacation start/end dates in the user's timezone (6235)**

The vacation preferences store their start/end dates as epoch seconds at
midnight in the *user's* timezone, but the sieve generator formatted them
back through the *sogod process* timezone when emitting the
`currentdate :value "ge"/"le" "date"` conditions of the vacation script.
Whenever the host timezone differed from the user's SOGo timezone, the date
written to the Sieve script was shifted by one day.

AVANT — user in Europe/Paris picks "First day of vacation: 04/08/2026"
(epoch 1785801600 = 2026-08-03 22:00 UTC), sogod host runs at UTC:

```
require ["vacation","date","relational"];
if allof ( currentdate :value "ge" "date" "2026-08-03" ) { vacation ... }
```

The auto-reply actually starts on August 3rd instead of the 4th; with a host
timezone east of the user's, the script can equally show the day *after* the
selection (the exact symptom reported in ticket 6235).

APRES — the same UI selection now produces a date computed in the user's
SOGo timezone, via the new `+[SOGoSieveManager sieveDateFromEpoch:timeZone:]`
helper, consistent with the `:zone` offset already emitted for the vacation
*time* conditions and with `sogo-tool update-autoreply`:

```
require ["vacation","date","relational"];
if allof ( currentdate :value "ge" "date" "2026-08-04" ) { vacation ... }
```

The written date now always matches the web UI selection, whatever timezone
the sogod process runs in. Covered by the new unit test
`test_sieveDateFromEpoch_userTimeZone` (271/271 tests pass).
