# Bug 6133 — Timezone updates not being taken into account

## Root cause

Two layers, one bug:

1. **Primary (already fixed upstream, present in our branch)** — `SOPE/NGCards/iCalDateTime.m:86-98`
   (`-timeZone`, upstream commit 244d1388, imported here via d902756aa): SOGo trusted the
   event's inline VTIMEZONE to resolve a TZID. Thunderbird/Evolution ship stale VTIMEZONEs
   for zones that abolished DST (Brazil 2019, Chile…), so SOGo resolved `America/Sao_Paulo`
   to -0200 for 2025 dates and stored startdates one hour early. The upstream fix prefers
   `[iCalTimeZone timeZoneForName:]` (SOGo's own vzic/IANA database shipped under
   `SOPE/NGCards/TimeZones/`) and only falls back to the inline VTIMEZONE.

2. **Residual (fixed by this branch)** — `SOPE/NGCards/iCalTimeZonePeriod.m:298-304`
   (`-occurrenceForDate:`): when a period's RRULE carries an `UNTIL` in the past of the
   reference date, the method returned **nil**, making that period invisible to
   `iCalTimeZone _occurrenceForPeriodNamed:forDate:` (iCalTimeZone.m:186-218). The final
   `STANDARD` rule (`UNTIL=20190217`) therefore dropped out of the comparison in
   `periodForDate:` and the latest `DAYLIGHT` period (2018-11-04, -0200) won for any
   post-2019 date — the exact 1-hour shift of the ticket. This path is still live whenever
   the TZID is absent from the NGCards IANA database (custom IDs such as
   `/mozilla.org/…/America/Sao_Paulo`, `tzone://Microsoft/…`, or deployments without the
   timezone resources installed).

## What changed

`SOPE/NGCards/iCalTimeZonePeriod.m` — one branch collapsed:

- **Before**: a refDate past the rule's UNTIL got an occurrence only if the
  refDate-year occurrence preceded the UNTIL (same-year case); otherwise `nil`.
- **After**: any refDate at/after the UNTIL resolves the period's last occurrence to the
  UNTIL date itself (RFC 5545: UNTIL is inclusive — the rule's last transition), so the
  period stays a candidate and `periodForDate:` correctly picks the latest transition
  at-or-before the date.

Demonstrated live on the e2e stack (deployed build = upstream fix only), same VTIMEZONE,
events at 11:00 `America/Sao_Paulo` (= 14:00 UTC):

- AVANT (custom TZID, fallback path): `FREEBUSY;FBTYPE=BUSY:20261007T130000Z/20261007T140000Z` — one hour early.
- APRÈS (IANA TZID, reference): `FREEBUSY;FBTYPE=BUSY:20261005T140000Z/20261005T150000Z` — correct.

With this branch, the fallback path yields the same -0300 result as the IANA path
(locked by unit tests below); no new code paths, no API changes.

## Tests

`Tests/Unit/TestiCalTimeZoneFallback.m` (registered in `Tests/Unit/GNUmakefile`), using the
ticket's two VTIMEZONEs verbatim (reduced Mozilla history + Evolution `calendar-2.ics`):

- `test_offsetBeyondLastTransition` — 2025 and post-Feb-2019 dates resolve -10800;
  dates inside the 2018 DST window still resolve -7200; southern winter 2015 -10800;
  Evolution-style zone: 2025 -10800, DST 2018 -7200.
- `test_eventStartDateBeyondLastTransition` — DTSTART/DTEND epochs: Mozilla
  2025-06-24 11:00→`1750773600` (14:00 UTC), Evolution 2025-07-10 10:00→`1752152400`
  (13:00 UTC); both were one hour early before the fix.
- `test_offsetWithRecurringRules` — regression guard: Europe/Berlin stays +7200 summer /
  +3600 winter (rules without UNTIL untouched).

Suite result: 218 tests, 0 new failures (only the two documented host-noise failures
`test_NGInternetSocketAddressFromString`, `test_stringWithoutHTMLInjection`).

## Verification steps for the orchestrator

Unit (host):

```
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c16-6133
# expect: Ran 218 tests, only the two known host-noise failures
```

E2E residual-defect repro on the deployed stack (before this fix is deployed; artifacts
must be cleaned up afterwards):

```
# 1. create scratch calendar
curl -s -u sogo-tests1:sogo -X MKCALENDAR http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Calendar/test-6133-tz/
# 2. PUT an ics with the ticket's VTIMEZONE twice: once TZID=America/Sao_Paulo,
#    once TZID=/mozilla.org/20070129_1/America_Sao_Paulo, both
#    DTSTART;TZID=...:20261005T110000 / DTEND ...T120000
# 3. check the stored busy time:
curl -s -u sogo-tests1:sogo "http://127.0.0.1:50001/SOGo/dav/sogo-tests1/freebusy.ifb" | grep FREEBUSY
#    pre-fix deployed build: IANA TZID -> 20261005T140000Z/150000Z (ok)
#                            mozilla TZID -> 20261005T130000Z/140000Z (one hour early)
#    after deploying this branch: both -> 140000Z/150000Z
# 4. cleanup: DELETE each event and the test-6133-tz calendar
```

The exact scratch ics used are reproducible from the unit-test constants in
`Tests/Unit/TestiCalTimeZoneFallback.m` (`tzMozilla`/`tzEvolution`).

## PR body draft

When Thunderbird or Evolution sends an invitation for a timezone that has since dropped
DST (e.g. `America/Sao_Paulo`, no DST since 2019), the client still attaches the full
historical VTIMEZONE whose last DAYLIGHT entry dates from 2018 and whose final STANDARD
rule carries `UNTIL=20190217`. SOGo's VTIMEZONE evaluator dropped any period whose RRULE
had already expired, so for post-2019 dates the 2018 DAYLIGHT period (-0200) won over the
final STANDARD rule and events were stored one hour early: an 11:00 São Paulo meeting
(16:00 CEST) appeared at 15:00 CEST in the web UI and notifications — exactly bug 6133.
The already-merged IANA-first lookup (244d1388) masks this for standard TZIDs, but the
defect remained reachable for custom TZIDs (`/mozilla.org/…`, `tzone://Microsoft/…`)
verified live on the e2e stack: the same invitation stored at 13:00Z instead of 14:00Z
when the TZID was not an IANA name.

This PR fixes the evaluator: when a reference date is past a period's RRULE UNTIL, the
period's last occurrence is now its UNTIL date (inclusive per RFC 5545) instead of nil,
so `periodForDate:` picks the genuinely last transition at-or-before the date. The change
is one branch in `iCalTimeZonePeriod occurrenceForDate:`; the only caller is
`iCalTimeZone _occurrenceForPeriodNamed:forDate:`. Unit tests lock the ticket's exact
VTIMEZONEs (Mozilla full-history and Evolution `calendar-2.ics`): 2025 dates resolve
-0300 with correct event epochs, the 2018 DST window still resolves -0200, and
still-DSTing zones (Europe/Berlin) are unchanged.
