# Bug 6191 — edited URL property is re-saved as ATTACH (RFC 5545 violation)

Branch: `fix-6191-mantis` — commit `773a8dc61` — `fix(calendar): save edited URL property back to URL instead of ATTACH (bug 6191)`

## Root cause (file:line)

The web editor shows ATTACH properties **and** the VEVENT `URL` property
(RFC 5545 §3.8.4.6) in a single editable list, but the two were
indistinguishable in the save payload:

- **Read** — `-[UIxComponentEditor attachUrls]` (before the fix,
  `UI/Scheduler/UIxComponentEditor.m:595-625`): ATTACH values were
  returned as `{value: ...}` dictionaries and the URL property value was
  appended with **no marker**. (It also appended a phantom
  `{"value": ""}` entry for events without a URL, because
  `+[NSURL URLWithString:@""]` is non-nil on GNUstep.)
- **Write** — `-[UIxComponentEditor setAttributes:]`
  (`UI/Scheduler/UIxComponentEditor.m:660-687`): all existing ATTACH
  children were removed, then every submitted value was written back as
  an ATTACH, **except** values equal to the current URL property
  (dedup). The URL property itself was never updated nor removable.

So when a user *edited* the URL row (e.g. `https://www.uni-ulm.de` →
`https://www.uni-ulm.de/icq`), the new value no longer matched the
original URL: it landed in ATTACH while the original URL stayed → two
links, and iOS shows the ATTACH one as a broken attachment (an ATTACH
that is not a downloadable document).

Reproduced live on the shared stack (sogo-tests3): CalDAV PUT of an
event with `URL;VALUE=URI:https://www.uni-ulm.de`, then a web-editor
`save` POST with `attachUrls:[{"value":"https://www.uni-ulm.de/icq"}]`
produced exactly the ticket's ICS: unchanged `URL:` **plus**
`ATTACH:https://www.uni-ulm.de/icq`.

## What changed (before/after)

Implementation of the reporter's resolution **C** ("allow editing the
URL property, but save it back to URL instead of ATTACH"), plus
recommendation **2** (label). The merge/split logic moved verbatim into
a testable category on `iCalEntityObject`
(`SoObjects/Appointments/iCalEntityObject+SOGo.m:369-431`):

| | Before | After |
|---|---|---|
| view JSON of URL property | `{value}` — indistinguishable from ATTACH | `{value, isUrl: true}` (flag round-trips through the AngularJS editor: `ng-model` keeps object identity, `$omit` deep-copies) |
| save of an **edited** URL row | new value written as **ATTACH**, old URL kept → two links | flagged value written back to the **URL** property (`-[iCalEntityObject setUrl:]`), no ATTACH twin |
| save without any `isUrl` flag (legacy/API clients) | dedup: values equal to the URL property skipped, URL untouched | **identical** (legacy fallback preserved) |
| deleting/clearing the URL row | URL property kept | unchanged (URL kept — conservative, iOS treats URL as immutable) |
| event with ATTACH but no URL | view JSON carried a trailing phantom `{"value": ""}` row | phantom row gone |
| editor row labels | every row labelled "URL" | URL-property row: "URL"; attachment rows: "Document URL" (`UIxAppointmentEditorTemplate.wox:144-145`, `UIxTaskEditorTemplate.wox:112-113`), key added to all 47 `UI/Scheduler/*.lproj/Localizable.strings` (translated for fr/de/es/it/pt/nl/da/sv/no, English elsewhere, following the existing untranslated-key convention) |

`UIxComponentEditor attachUrls` / `setAttributes:` now delegate to the
category (`-[iCalEntityObject attachUrlsForEditor]` /
`-setAttachUrlsFromEditor:`); invalid entries (non-dict, missing/empty
value) are ignored instead of risking `addObject:nil`.

## Tests

- New `Tests/Unit/TestiCalEntityObjectAttachUrls.m` (registered in
  `Tests/Unit/GNUmakefile`), 8 tests covering every branch of both
  methods: getter with URL+ATTACH (flag position/value), ATTACH-only
  (no phantom entry), edited URL saved back to URL with no ATTACH,
  edited URL + resubmitted ATTACH kept, legacy unflagged submission
  (dedup + URL preserved), unflagged submission does not delete the URL
  property, invalid entries ignored (non-dict, no value key, empty
  value, empty flagged value), empty flagged value leaves URL
  unchanged. Execution proven by mutation (broken assertion → FAIL,
  restored).
- Full suite: `local/run-worktree-tests.sh ~/Projets/hadrienblanc/sogo/wt/c10-6191`
  → **79 tests, 2 failures**, both pre-documented host noise
  (`test_NGInternetSocketAddressFromString`, `test_stringWithoutHTMLInjection`).
- `UI/SOGoUI`, `UI/Common`, `UI/Scheduler` compile and link against the
  change (copied the main checkout's generated `config.make` into the
  worktree — worktrees don't carry untracked build files).

## Verification steps for the orchestrator

Reproduction artifacts were cleaned up (both test events deleted,
204). After deploying this branch to the e2e stack, rerun:

```bash
U=sogo-tests3; P=sogo; D=/tmp/opencode/rep6191
curl -s -o /dev/null -w 'PUT: %{http_code}\n' -u $U:$P -X PUT \
  -H 'Content-Type: text/calendar; charset=utf-8' \
  --data-binary @$D/test-6191-url.ics \
  http://127.0.0.1:50001/SOGo/dav/$U/Calendar/personal/test-6191-urlattach.ics
curl -s -c $D/cookies.txt -H 'Content-Type: application/json' \
  -d '{"userName":"'$U'","password":"'$P'"}' http://127.0.0.1:50001/SOGo/connect
# 1. view must flag the URL entry:  "attachUrls":[{"value":"https://www.uni-ulm.de","isUrl":true}]
curl -s -b $D/cookies.txt http://127.0.0.1:50001/SOGo/so/$U/Calendar/personal/test-6191-urlattach.ics/view
# 2. save the EDITED url as the web UI would (flag round-trip)
XSRF=$(grep XSRF $D/cookies.txt | awk '{print $7}')
curl -s -b $D/cookies.txt -H "X-XSRF-TOKEN: $XSRF" -H 'Content-Type: application/json' -X POST \
  -d '{"attachUrls":[{"value":"https://www.uni-ulm.de/icq","isUrl":true}],"summary":"test-6191 URL edit","location":"office","classification":"confidential","isAllDay":0,"startDate":"2026-04-30","startTime":"15:15","endDate":"2026-04-30","endTime":"16:15","timezone":"Europe/Berlin","sendAppointmentNotifications":0,"pid":"personal","destinationCalendar":"personal"}' \
  http://127.0.0.1:50001/SOGo/so/$U/Calendar/personal/test-6191-urlattach.ics/save
# 3. ICS must contain URL:https://www.uni-ulm.de/icq and NO ATTACH
curl -s -u $U:$P http://127.0.0.1:50001/SOGo/dav/$U/Calendar/personal/test-6191-urlattach.ics | grep -E 'URL|ATTACH'
# cleanup
curl -s -o /dev/null -w 'DELETE: %{http_code}\n' -u $U:$P -X DELETE \
  http://127.0.0.1:50001/SOGo/dav/$U/Calendar/personal/test-6191-urlattach.ics
```

- BEFORE fix (measured): step 3 returns `URL;VALUE=URI:https://www.uni-ulm.de` +
  `ATTACH:https://www.uni-ulm.de/icq`.
- AFTER fix (expected): step 1 flags `"isUrl":true`; step 3 returns only
  `URL:https://www.uni-ulm.de/icq` (no ATTACH).
- Unit suite: `local/run-worktree-tests.sh ~/Projets/hadrienblanc/sogo/wt/c10-6191`.
- Source of `test-6191-url.ics` kept at `/tmp/opencode/rep6191/test-6191-url.ics`
  (event with `URL;VALUE=URI:https://www.uni-ulm.de`, UID `test-6191-urlattach`).

## PR body draft

Bug 6191 — a VEVENT carrying a URL property (RFC 5545 §3.8.4.6, e.g.
added from iOS Calendar) is shown as a clickable link in the web
calendar, but the editor merges it into the attachment list with no
marker. On save, the code only skipped values *equal* to the existing
URL property and wrote everything else to ATTACH — so editing the link
produced both an unchanged `URL:` and a new `ATTACH:` (two links), and
iOS then shows a broken "attachment" since the URL is not a downloadable
document. Reproduced on the dev stack exactly as in the ticket.

AVANT: edit `https://www.uni-ulm.de` → `https://www.uni-ulm.de/icq` in
the web editor → ICS keeps `URL;VALUE=URI:https://www.uni-ulm.de` and
gains `ATTACH:https://www.uni-ulm.de/icq`; the attachment is unusable on
iOS. APRÈS: the view payload flags the URL-sourced entry
(`isUrl: true`, round-tripped through the AngularJS editor), and a
flagged value is saved back to the `URL` property — the ICS ends with a
single `URL:https://www.uni-ulm.de/icq` and no ATTACH twin. Unflagged
payloads keep the legacy dedup behaviour (API clients unaffected),
attachment rows are now labelled "Document URL" (47 locales), the
phantom empty URL row is gone, and 8 new unit tests cover every branch
of the merge/split logic (suite: 79 tests, only the two known host-noise
failures).
