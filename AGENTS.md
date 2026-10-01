# AGENTS.md

Bug reports and feature requests live on Mantis (https://bugs.sogo.nu), not on GitHub issues — scrape and triage open tickets there before picking work (dump of open tickets: `local/issues/mantis_open.json`).

## Orchestrator layout — the `experimental` workflow

One Mantis ticket = one dev change = one PR merged into `experimental`.

- **Main checkout** `~/Projets/hadrienblanc/sogo/sogo` — stays on `experimental`. Only the orchestrator uses it: review, e2e deploys, PRs, merges.
- **Worktrees** `~/Projets/hadrienblanc/sogo/wt/<id>-<slug>/` — one per ticket, branch `fix-<id>-<slug>` based on `experimental`. Sub-agents work exclusively inside their own worktree.
- **Unit tests** (per worktree): `local/run-worktree-tests.sh ~/Projets/hadrienblanc/sogo/wt/<id>-<slug>` (the first run builds the worktree's SOPE objects and SOGo framework — a few minutes). Known host-specific failures to ignore on a clean tree: `test_NGInternetSocketAddressFromString` (dual-stack localhost) and `test_stringWithoutHTMLInjection` (GNUstep-base empty-template regex quirk).
- **e2e stack** — docker compose at `local/e2e/`, SOGo at `http://127.0.0.1:50001` (basic auth `sogo-tests1/2/3` or `sogo-tests-super`, password `sogo`), MySQL, Dovecot (IMAP `:1430`, sieve `:4191`), Postfix `:2500`. Sub-agents may use it **read/write for reproductions only** (curl/PUT/POST, distinct folders per agent); **deploys, container rebuilds and sogod restarts are orchestrator-only**.
- **Conventions**: conventional commits, no code comments, minimal diffs, GNUstep manual retain/release style, every fix lands with tests (unit in `Tests/Unit`, e2e spec in `Tests/spec` when a stack is needed).
- Sub-agents never `git push`, never open PRs, never merge — they leave commits on their worktree branch and report back.
- **Coverage goal on `experimental`: 100% of the code paths we touch** — a fix is not done until its branches (including error paths) are exercised by a test.

## Field notes (learned the hard way)

- The `sogo-static-files` named volume shadows freshly built images: rebuilding the image does NOT update the running stack. Either `docker rm -f sogo_dev sogo_httpd && docker volume rm sogo-e2e_sogo-static-files && docker compose up -d`, or hot-deploy into the running container (docker cp + make + cp into /usr/local/lib/GNUstep).
- jasmine `--filter` matches the full spec title (describe + it), not the file name.
- The vacation sieve specs can flake under load (dovecot auth worker starvation from rapid managesieve logins) — rerun in isolation before blaming a change.
- When merging several agent branches: they all touch `Tests/Unit/GNUmakefile`; resolve by keeping every added test file and every added link flag.

## Handy reference

- Unit suite runner: `local/run-worktree-tests.sh <worktree>`
- e2e jasmine (inside the `sogo_dev` container): `cd /workspace/Tests && sed -i 's/port: "50001"/port: "50000"/' lib/config.js && npx jasmine --config=spec/support/jasmine.json` (restore `lib/config.js` afterwards)
- Mantis ticket detail: `curl -s "https://bugs.sogo.nu/view.php?id=<n>"`
