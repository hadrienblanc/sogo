# Bug 6129 — `NSPropertyList.m: 1009. In parsePlItem Missing semicolon in dictionary` in `sogo-tool update-autoreply` cron

**Verdict: NOT a SOGo bug.** The message is a *warning* (not an error) emitted by
**GNUstep-base's** old-style property-list parser when a dictionary's last entry
omits its terminating `;` right before `}` — i.e. a syntax slip in an
environment file on the reporter's server (almost certainly
`/etc/sogo/sogo.conf`). GNUstep tolerates the syntax, parses the file
successfully, and SOGo keeps working — which is exactly why the cron output
shows the warning followed by `Enabled auto-reply of user xxx`. The reporter
never replied to the maintainer's `feedback`; the reporter's fix is one `;` in
their config (or dropping the now-obsolete cron, as the sieve `date` extension
made `update-autoreply` unnecessary).

## Root cause (file:line)

- Emission site: `NSWarnFLog(@"Missing semicolon in dictionary at line %d char %d", ...)`
  in `parsePlItem()`, `Source/NSPropertyList.m` of **gnustep-base** — line **1009**
  in base-1_29_0 (Ubuntu 24.04's package; verified against the tag). It fires when a
  `key = value` pair is followed directly by `}` (no `;`): unless
  `GSMacOSXCompatible` is set, GNUstep **warns and continues**; the dictionary is
  returned intact.
- SOGo call site reached at `sogo-tool` startup:
  `SoObjects/SOGo/SOGoSystemDefaults.m:98` (`[NSDictionary dictionaryWithContentsOfFile:]`
  in `_injectConfigurationFromFile`) reading `/etc/sogo/sogo.conf` (and
  `/etc/sogo/debconf.conf`); `.GNUstepDefaults` is read the same way at startup by
  `NSUserDefaults`.
- Why not the per-user profile path (`SoObjects/SOGo/SOGoUserProfile.m:122`,
  `_convertPListToJSON:`)? That path is only reached after `isJSONString` fails,
  which first logs SOGo-side errors (`json parser: … attempting once more after
  unescaping…`, `total failure. Original string is: …` — `NSString+Utilities.m:855/863`).
  None of those lines appear in the report, while the warning is the **first** line,
  emitted at process start (16:30:01.776) *before* `SOGoCache` init — matching the
  config-file read in `SOGoSystemDefaults +initialize`, before any DB/sieve work.
- The message geometry confirms it: `line 169 char 6722` are the 1-based line index
  and **absolute** char offset of the offending `}` (`pld->lin + 1`, `pld->pos + 1`)
  — the closing brace of a dictionary at the end of a ~169-line, ~6.7 KB file: a
  typical hand-maintained `sogo.conf` (stored profile JSON is a single line, and
  GNUstep-written `.GNUstepDefaults` always carries semicolons).

### Reproducer (no SOGo code involved)

```bash
printf '{\n  foo = bar;\n  baz = qux\n}\n' > /tmp/bad.conf
```
Reading it with `[NSDictionary dictionaryWithContentsOfFile:]` under the local
GNUstep 1.31.1 prints:

```
File NSPropertyList.m: 1008. In parsePlItem Missing semicolon in dictionary at line 4 char 28
```

…**and returns a valid dictionary** (`{baz = qux; foo = bar; }`). Same
message modulo the line offset dictated by the gnustep-base version.
Under cron, stderr lands in the daily mail even though the run succeeded.

### What the reporter should do

Add the missing `;` before the `}` at (or near) line 169 of
`/etc/sogo/sogo.conf` — look for the end of the last dictionary (e.g. a
`SOGoUserSources` entry or the top-level dict itself). Alternatively drop the
cron entirely: with sieve servers supporting the `date` extension, SOGo handles
vacation activation/expiry itself (see the maintainer's note and the
installation guide section "Cronjob vacation messages activation and
expiration").

## What changed (before/after)

**No production code change** — the defect is not in SOGo, and SOGo cannot
suppress or intercept GNUstep's internal `NSWarnFLog`. Making the lenient
syntax fatal would break working setups, and re-implementing plist linting in
SOGo would duplicate the parser for no functional gain.

Tests only, adding previously absent coverage for the SOGo-owned machinery on
this code path (`SOGoUserProfile`'s legacy-value conversion, which is what
people land on when chasing this error message):

- **Before**: `SOGoUserProfile._convertPListToJSON:` (SoObjects/SOGo/SOGoUserProfile.m:122-150)
  had zero test coverage: no test for legacy plist values, nor for the
  unparsable-value fallback to `{}`.
- **After**: `Tests/Unit/TestSOGoUserProfile.m` (registered in `Tests/Unit/GNUmakefile`)
  locks:
  1. `test_convertPListToJSON_legacyPlistValue` — an old-style plist profile
     converts to JSON and round-trips through `objectFromJSONString`;
  2. `test_convertPListToJSON_legacyPlistMissingFinalSemicolon` — a plist whose
     final entries omit their `;` before `}` (the exact shape triggering bug
     6129's warning) **still converts** — documenting GNUstep's lenient parse;
     the test's stderr shows the very warning from the ticket
     (`File NSPropertyList.m: 1008. In parsePlItem Missing semicolon in dictionary…`);
  3. `test_convertPListToJSON_unparsableValueYieldsEmptyJSON` — a value that is
     neither JSON nor a plist yields `{}` (error branch).

## Tests

```
$ local/run-worktree-tests.sh ~/Projets/hadrienblanc/sogo/wt/c16-6129
...
Ran 221 tests
FAILED (2 failures, 0 errors)
```

The only 2 failures are the documented host-noise failures to ignore on a clean
tree (`test_NGInternetSocketAddressFromString`, `test_stringWithoutHTMLInjection`).
The 3 new `TestSOGoUserProfile` tests pass.

## Verification steps for the orchestrator

1. Full unit suite (expect only the 2 known host-noise failures):
   ```
   /home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c16-6129
   ```
2. Focus check — the new tests' behaviour is visible in the suite output:
   - `database value for defaults profile (uid: 'test-6129') is a plist` (cases 1 & 2),
   - the ticket's warning text `In parsePlItem Missing semicolon in dictionary`
     printed by case 2, followed by a passing `.`,
   - `failed to parse property list value … extra data after parsed string`
     followed by a passing `.` (case 3).
3. Standalone root-cause demo (independent of the worktree, read-only):
   ```
   printf '{\n  foo = bar;\n  baz = qux\n}\n' > /tmp/opencode/test-6129-bad.conf
   # then read it with NSDictionary dictionaryWithContentsOfFile: under GNUstep
   # → "File NSPropertyList.m: … Missing semicolon in dictionary" + dict parses fine
   ```
   (`test-6129-bad.conf` in `/tmp/opencode` is disposable; nothing was written
   to the shared e2e stack for this ticket — no stack-side repro was needed.)

## PR body draft

> ### Bug 6129 — "NSPropertyList.m: 1009. In parsePlItem Missing semicolon in dictionary" from the update-autoreply cron
>
> ** Investigation.** The daily `sogo-tool update-autoreply -p /etc/sogo/sieve.creds`
> cron mailed `File NSPropertyList.m: 1009. In parsePlItem Missing semicolon in
> dictionary at line 169 char 6722`, yet the run completed (`Enabled auto-reply
> of user xxx`). That message is a *warning* from GNUstep-base's old-style
> property-list parser (`parsePlItem`, gnustep-base 1.29 — line 1009 there):
> when the last entry of a dictionary omits its `;` right before `}`, GNUstep
> warns but still parses the file successfully. The position ("line 169 char
> 6722") is the line and absolute character offset of that `}` — i.e. the end
> of a dictionary in a ~169-line, ~6.7 KB file, which matches the reporter's
> hand-maintained `/etc/sogo/sogo.conf`, read by `SOGoSystemDefaults` at every
> tool startup. It is not SOGo's per-user profile fallback: that path always
> logs SOGo-side JSON errors first, and none appear in the report; the warning
> also precedes `SOGoCache` init, pinning it to config loading.
>
> **Outcome.** This is a configuration typo, not a SOGo defect — SOGo cannot
> intercept GNUstep's internal warning, and tightening the syntax would break
> lenient-but-working setups. The fix for the reporter is the missing `;` near
> line 169 of `/etc/sogo/sogo.conf`, or retiring the cron now that sieve's
> `date` extension handles vacation expiry natively. This PR therefore changes
> no production code; it locks the neighbouring SOGo-owned behaviour that had
> zero coverage — `SOGoUserProfile`'s conversion of legacy (plist) profile
> values to JSON, including values parsed leniently despite missing final
> semicolons (the exact condition behind the ticket's warning), and the
> unparsable-value fallback to `{}`.
