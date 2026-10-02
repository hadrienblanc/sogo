# Bug 5908 — "Error in apache log (alias directive will never match...)"

**Verdict: NOT an SOGo bug.** The two `Alias` directives shipped in
`Apache/SOGo.conf` do not overlap each other; the AH00671 warnings reported
occur only when the SOGo configuration file is parsed a second time by Apache
(e.g. included twice), which happens on the reporter's system, not in the
shipped file. No production change was made; the analysis is locked by unit
tests.

## Root cause (file:line)

- `Apache/SOGo.conf:1-4` ships:
  - `Alias /SOGo.woa/WebServerResources/ /usr/lib/GNUstep/SOGo/WebServerResources/`
  - `Alias /SOGo/WebServerResources/ /usr/lib/GNUstep/SOGo/WebServerResources/`
- Apache ≥ 2.4.56 emits `AH00671` in `add_alias_internal()`
  (`modules/mappers/mod_alias.c`, overlap-check loop) when the new alias's
  fake path is matched by an **earlier** alias through `alias_matches()`
  (`mod_alias.c`, `alias_matches()` — segment-based prefix matching).
- `alias_matches("/SOGo/WebServerResources/", "/SOGo.woa/WebServerResources/")`
  returns 0 and the converse also returns 0: `/SOGo.woa` and `/SOGo` are
  distinct path segments, so the two shipped directives cannot shadow each
  other. A single clean inclusion of `Apache/SOGo.conf` emits no AH00671.
- The reporter gets warnings on **both** line 1 and line 2 simultaneously. A
  pre-existing `Alias /SOGo` would only explain the line 2 warning
  (`alias_matches("/SOGo.woa/...", "/SOGo") == 0`). The only configuration
  that reproduces the exact reported symptom is **SOGo.conf being included
  twice** in the Apache parse order (openSUSE classic: `conf.d/*.conf` glob
  plus `APACHE_CONF_INCLUDE_FILES`, or a leftover copy in another included
  file). On the second parse, each directive duplicates an earlier one,
  mod_alias keeps the first match (`try_alias_list()` scans in declaration
  order), and Apache logs the warnings "at line 1" / "at line 2".
- Christian Mack's comment (~0017642) is confirmed, with one nuance: Apache
  is not "wrong" — its heuristic correctly detects duplicate directives
  somewhere earlier in the *reporter's* parse order; the shipped file itself
  is internally consistent.
- Deleting the two lines, as the reporter asked, would break static
  resources (JS/CSS/images) under one or both URL prefixes — both forms are
  live URL spaces of SOGo's Web UI.

Empirical proof (verbatim C port of mod_alias 2.4.x `alias_matches()` +
overlap check, `/tmp/opencode/alias5908.c` during the session):

```
== shipped Apache/SOGo.conf (clean single include) ==
  [1] /SOGo.woa/WebServerResources/            -> ok
  [2] /SOGo/WebServerResources/                -> ok
== SOGo.conf included TWICE ==
  [1] /SOGo.woa/WebServerResources/            -> ok
  [2] /SOGo/WebServerResources/                -> ok
  [3] /SOGo.woa/WebServerResources/            -> AH00671 overlap warning
  [4] /SOGo/WebServerResources/                -> AH00671 overlap warning
== earlier 'Alias /SOGo' hypothesis ==
  [2] /SOGo.woa/WebServerResources/            -> ok
  [3] /SOGo/WebServerResources/                -> AH00671 overlap warning
```

## What changed (before/after)

- Before: no test coverage of the shipped Apache aliases; nothing prevents a
  future edit from introducing an actual self-overlapping/duplicated `Alias`
  in `Apache/SOGo.conf`.
- After (test-only, no runtime/production change):
  - `Tests/Unit/TestApacheAliasDirectives.m` — ports mod_alias's
    `alias_matches()` semantics and, reading the real `../../Apache/SOGo.conf`
    (backslash continuations handled):
    - both WebServerResources prefixes are aliased to the same directory;
    - a single clean inclusion produces zero overlaps (no AH00671);
    - including the file twice flags exactly the two duplicate directives —
      reproducing bug 5908's log;
    - segment-boundary semantics (`/SOGo.woa/...` is not under `/SOGo`).
  - `Tests/Unit/GNUmakefile` — registers the new test file.
- Recommended admin guidance for the reporter (not a code change): include
  SOGo.conf exactly once (on openSUSE, check `APACHE_CONF_INCLUDE_FILES` in
  `/etc/sysconfig/apache2` vs the `conf.d/*.conf` glob); the warnings then
  disappear. The two `Alias` lines must be kept.

## Tests

- `local/run-worktree-tests.sh wt/c33-5908`:
  `Ran 234 tests` (229 baseline + 5 new), `FAILED (2 failures, 0 errors)` —
  the 2 failures are the documented host-noise
  (`test_NGInternetSocketAddressFromString`,
  `test_stringWithoutHTMLInjection`).
- New tests (all passing):
  - `test_shippedConfExposesBothWebServerResourcesPrefixes`
  - `test_shippedConfDoesNotTriggerApacheOverlapWarning`
  - `test_confIncludedTwiceReproducesBug5908Warnings`
  - `test_aliasMatchesComparesWholePathSegmentsOnly`
  - `test_sogoWebServerResourcesAliasesDoNotOverlapEachOther`
- Note: the test binary segfaults **after** printing its final report on this
  host; verified pre-existing (true baseline without my change: 229 tests,
  same exit 139) and unrelated to this ticket.

## Verification steps for the orchestrator

```
# 1. unit suite (234 tests, only the 2 known host-noise failures)
rm -f wt/c33-5908/Tests/Unit/obj/sogo-tests   # avoid gnustep-make stale-link trap
local/run-worktree-tests.sh wt/c33-5908 | tail -5

# 2. inspect the change
git -C wt/c33-5908 show --stat HEAD

# 3. optional read-only sanity: SOGo itself is served fine behind such a config
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:50001/SOGo/
```

(No `test-5908-*` artifacts were created on the shared stack; only read-only
GETs were performed. Static-file probes on the dev stack 404 because the
`sogo-static-files` volume isn't populated — orchestrator-managed, out of
scope here.)

## PR body draft

Depuis Apache 2.4.56, mod_alias émet l'avertissement AH00671 ("The Alias
directive ... will probably never match because it overlaps an earlier
Alias") dès qu'une directive Alias est masquée par une directive équivalante
déclarée plus tôt dans l'ordre d'analyse. Le fichier `Apache/SOGo.conf` livré
avec SOGo déclare deux Alias — `/SOGo.woa/WebServerResources/` et
`/SOGo/WebServerResources/` — qui servent le même répertoire sous deux
espaces d'URL utilisés par l'interface. L'analyse des sémantiques de
mod_alias (`alias_matches()`, comparaison par segments de chemin complet)
montre que ces deux directives ne se recouvrent pas et qu'une inclusion
unique du fichier ne produit aucun avertissement.

AVANT (bug 5908, config où SOGo.conf est inclus deux fois) :

```
AH00671: The Alias directive in /etc/apache2/conf.d/SOGo.conf at line 1 will probably never match because it overlaps an earlier Alias.
AH00671: The Alias directive in /etc/apache2/conf.d/SOGo.conf at line 2 will probably never match because it overlaps an earlier Alias.
```

APRÈS (include unique de SOGo.conf, aucune modification de configuration
SOGo requise) : plus aucun AH00671 au démarrage d'Apache, les ressources
statiques restent servies sous les deux préfixes. Ce changement n'ajoute
aucun code de production : il verrouille par des tests unitaires
(`Tests/Unit/TestApacheAliasDirectives.m`, portage fidèle des sémantiques de
mod_alias) le fait que le fichier livré ne se recouvre pas lui-même et
qu'une double inclusion — et elle seule — reproduit les avertissements
signalés. Les deux lignes Alias doivent être conservées ; la correction côté
administrateur consiste à n'inclure SOGo.conf qu'une seule fois (sur
openSUSE, vérifier `APACHE_CONF_INCLUDE_FILES` face au glob `conf.d/*.conf`).
