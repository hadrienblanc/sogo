# Ticket 5909 — "Improve log message" (ActiveSync, minor)

## Verdict: real (minor) defect — ambiguous log message; SOGo already handles the cleanup itself

The reporter (modir) is right: the log line emitted when an EAS client
resumes with a stale syncKey does not say who acts next. Reading the code
answers the reporter's question definitively: **nobody has to run
`sogo-tool`** — `SOGoActiveSyncDispatcher+Sync.m` performs the cache cleanup
by itself, in the same Sync response, driven by the `cleanup_needed` flag:

- `ActiveSync/SOGoActiveSyncDispatcher+Sync.m:1093-1100` — entries older than
  the filter are SoftDelete-re-armed so the client converges on the next sync;
- `ActiveSync/SOGoActiveSyncDispatcher+Sync.m:1194-1236` — GCS folders
  (contacts/events/tasks): cache entries are removed or reset;
- `ActiveSync/SOGoActiveSyncDispatcher+Sync.m:1524-1594` — mail folders:
  entries from the missed window are dropped from syncCache/dateCache and
  sequences reset to `0` so the changes are re-emitted.

So of the two wordings proposed in the ticket, only the second one is
factually correct ("SOGo initiates now a cache clean-up"); asking the
administrator to run `sogo-tool` would be wrong advice.

## Root cause (file:line)

`ActiveSync/SOGoActiveSyncDispatcher+Sync.m:1025` — the log line
`"Cache cleanup needed for device %@ - user: %@ syncKey: %@ cache: %@"`
states the problem but not the outcome, leaving administrators to guess
whether manual action (e.g. `sogo-tool`) is expected. No functional bug.

## What changed (before/after)

The message is now built by a pure helper
`+[NSString activeSyncCacheCleanupLogMessageForDevice:user:syncKey:cachedSyncKey:]`
(`ActiveSync/NSString+ActiveSync.m:46`), called from the dispatcher log site.
That file is compiled into both the ActiveSync bundle and the unit-test tool,
which makes the wording lockable by a unit test. The message prefix is kept
byte-identical so existing grep/alerting patterns keep matching.

AVANT:

```
[SOGoActiveSyncDispatcher]> Cache cleanup needed for device XXX - user: YYY syncKey: 195860-155278 cache: 195900-155278
```

APRES:

```
[SOGoActiveSyncDispatcher]> Cache cleanup needed for device XXX - user: YYY syncKey: 195860-155278 cache: 195900-155278 - SOGo initiates the cache cleanup automatically, no administrator action is required
```

No behavior, protocol or persistence change — log wording only.

## Tests

`Tests/Unit/TestNSString+ActiveSync.m` (registered in `Tests/Unit/GNUmakefile`):

- `test_cacheCleanupLogMessageKeepsPrefixAndStatesAutomaticHandling` — locks
  the exact message using the ticket's own values (device XXX / user YYY /
  syncKey 195860-155278 / cache 195900-155278): stable prefix + the new
  "automatic, no administrator action" clause;
- `test_cacheCleanupLogMessageInterpolatesArgumentsInOrder` — locks the
  argument order (device/user/syncKey/cached) with distinct values.

Full suite: `Ran 229 tests — FAILED (2 failures)`, the two known host-noise
failures (`test_NGInternetSocketAddressFromString`,
`test_stringWithoutHTMLInjection`), unrelated to this change.

No e2e spec: the message only appears in sogod logs during an EAS Sync
resumption with a stale syncKey; the shared stack runs the orchestrator's
build (deploys are orchestrator-only), so a live run could not exercise this
branch anyway. The unit test locks the contract.

## Verification steps for the orchestrator

```sh
# build + full unit suite of the worktree
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
  /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c33-5909

# prove the two new tests execute and pass (junit output)
cd /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c33-5909/Tests/Unit
source /home/hadrienblanc/Projets/hadrienblanc/sogo/local/env.sh
export LD_LIBRARY_PATH="$PWD/../../SOPE/NGCards/obj:$PWD/../../SOPE/GDLContentStore/obj:$PWD/../../SoObjects/SOGo/SOGo.framework/Versions/Current/sogo:$LD_LIBRARY_PATH"
./obj/sogo-tests -f junit 2>/dev/null | grep -A1 cacheCleanupLogMessage
# expect two <testcase> entries, no <failure> children
```

After the next stack rebuild/deploy, triggering any EAS Sync resumption with
a stale syncKey (e.g. replaying an old SyncKey from a paired device) must log
the APRES line above; `grep 'Cache cleanup needed' /var/log/sogo/sogo.log`
still matches.

## PR body draft

When an EAS client resumes a Sync with a syncKey that no longer matches the
cached one (typically after a missed response), SOGo logs
`Cache cleanup needed for device … syncKey: … cache: …` and then repairs the
situation by itself in the same Sync response: stale entries are dropped or
SoftDelete-re-armed so the device converges on the following sync cycles
(`SOGoActiveSyncDispatcher+Sync.m`). Bug 5909 reports that the message does
not say so: an administrator reading the log cannot tell whether running
`sogo-tool` is expected. It is not — the cleanup is fully automatic.

This keeps the existing prefix byte-for-byte (so log-parsing/alerting keeps
working) and appends an explicit resolution clause; the line is now built by
`+[NSString activeSyncCacheCleanupLogMessageForDevice:user:syncKey:cachedSyncKey:]`
and locked by unit tests (`Tests/Unit/TestNSString+ActiveSync.m`) covering
both the exact wording with the ticket's sample values and the argument
order. No functional change.

Refs: bugs.sogo.nu #5909
