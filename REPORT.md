# Ticket 6143 — Data Loss When Exporting Contacts with Multiple Phone Numbers

Branch: `fix-6143-mantis` (worktree `wt/c13-6143`)

## Root cause (file:line)

The bug is real and was reproduced live on the e2e stack. The stored vCard
keeps every `TEL` element (the web editor stores one child per phone,
`UI/Contacts/UIxContactEditor.m:311-327`), but the **web UI export** — both
"Export" on a single contact (`UI/WebServerResources/js/Contacts/Card.service.js:323`)
and "Export Address Book" (`AddressBook.service.js:731`) — posts to
`UIxContactFolderActions.exportAction` (`UI/Contacts/UIxContactFolderActions.m:74`),
which serializes each card through `-[SOGoContactGCSEntry ldifRecord]` →
`-[NGVCard (SOGoExtensions) asLDIFRecord]` (the reporter's "VCard" export is
this LDIF stream; SOGo 5's UI names the file `.ldif`).

In `SoObjects/Contacts/NGVCard+SOGo.m:428-460`
(`_simpleValueForType:inArray:excluding:`, now shifted to ~line 471), the
vCard→LDIF conversion resolved each phone key (`telephonenumber`, `homephone`,
`mobile`, `facsimiletelephonenumber`, `pager`) to a **single** value: it
enumerated the `TEL` children of the wanted type and stopped at the first
non-excluded match. The five `_setValue:to:` calls in `asLDIFRecord`
(pre-fix lines 576-595) therefore emitted only the first number of each
type; subsequent same-type numbers were silently dropped from the export —
exactly the reported data loss. Everything around this path already
supported multi-values: the LDIF writer renders one line per array element
(`SoObjects/Contacts/NSDictionary+LDIF.m:44-61`), the LDIF importer collects
repeated keys into arrays (`UIxContactFolderActions.m:263-271`), and the
LDIF→vCard importer expands arrays back into one `TEL` each
(`NGVCard+SOGo.m:189-238`, `_setPhoneValues:` / `addElementWithTag:ofType:withValue:`
— same pattern as past fixes 513d81eb5 / 96c22b6b9 for titles and other
multi-value attributes). Only the export collapsed the values.

## What changed (before/after)

`SoObjects/Contacts/NGVCard+SOGo.m` only (plus tests):

- New `_valuesForType:inArray:excluding:` — same matching/exclusion rules as
  `_simpleValueForType:inArray:excluding:` (which remains for emails/URLs),
  but collects **every** matching `TEL` value, skipping empty values.
- New `_setValue:toValues:inLDIFRecord:` — stores the array, or `@""` when
  empty (preserving the old "missing phone → empty key" behavior).
- `asLDIFRecord` now sets `telephonenumber`, `homephone`, `mobile`,
  `facsimiletelephonenumber` and `pager` to **arrays**, and the "voice"
  fallback (no work/home phone → use `TEL;TYPE=VOICE`) emits all voice
  numbers too; its emptiness check uses the collected arrays instead of
  `length` (which would not apply to arrays).

**AVANT** (live repro on the e2e stack, card stored with
`TEL;TYPE=WORK:+1 514 111 2222`, `TEL;TYPE=WORK:+1 514 333 4444`,
2× `CELL`, 1× `HOME`, 1× `FAX`; `POST …/Contacts/personal/export`):

```
telephonenumber: +1 514 111 2222      ← second WORK number lost
mobile: +1 514 777 8888               ← second CELL number lost
```

**APRÈS** (unit-tested through `asLDIFRecord` + `ldifRecordAsString`):

```
telephonenumber: +1 514 111 2222
telephonenumber: +1 514 333 4444
mobile: +1 514 777 8888
mobile: +1 514 999 0000
```

Re-importing such an LDIF recreates one `TEL` per line (round-trip test
below), and `TEL;TYPE=WORK,FAX` keeps being excluded from `telephonenumber`
and routed to `facsimiletelephonenumber`. `asLDIFRecord` has exactly one
consumer (`SOGoContactGCSEntry.ldifRecord`), whose only readers are the
export writer and the (template-unused) legacy editor accessor — both
array-safe.

## Tests

New `Tests/Unit/TestNGVCard+SOGo.m` (class `TestNGVCard_plus_SOGo`,
registered in `Tests/Unit/GNUmakefile`), loading the Contacts bundle and
parsing real vCard sources:

- `test_asLDIFRecordExportsAllPhonesOfSameType` — exact ticket scenario:
  2 WORK / 2 CELL / 1 HOME / 1 FAX / 1 pager all exported, in order.
- `test_asLDIFRecordExcludesFaxFromTypedPhones` — `WORK,FAX` stays out of
  `telephonenumber` and both fax numbers land in
  `facsimiletelephonenumber` (exclusion branch).
- `test_asLDIFRecordSkipsEmptyPhonesAndKeepsEmptyKeys` — empty `TEL:` values
  are skipped; a type with no numbers still yields `@""` keys (empty branch
  of `_setValue:toValues:`).
- `test_asLDIFRecordFallsBackOnVoicePhones` — the v2.1 `VOICE` fallback now
  emits every voice number.
- `test_ldifRecordAsStringRendersOneLinePerPhone` — final LDIF output: one
  `telephonenumber:`/`mobile:` line per number (counts checked).
- `test_updateFromLDIFRecordExpandsPhoneArrays` — import round-trip: the
  exported arrays recreate one `TEL;TYPE=WORK` per number.

Full suite: `Ran 171 tests — FAILED (2 failures)`, the 2 being the known
host-noise `test_NGInternetSocketAddressFromString` and
`test_stringWithoutHTMLInjection` (165 → 171 with the 6 new tests, all
passing).

## Verification steps for the orchestrator

```
# full unit suite (build + run; 171 tests, only the 2 known host-noise failures)
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c13-6143
# expected last lines:
#   Ran 171 tests
#   FAILED (2 failures, 0 errors)

# eyeball the new tests (165 -> 171 tests; failures stay at the 2 known ones):
cd /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c13-6143/Tests/Unit
source /home/hadrienblanc/Projets/hadrienblanc/sogo/local/env.sh
export LD_LIBRARY_PATH="../SOPE/NGCards/obj:../SOPE/GDLContentStore/obj:../SoObjects/SOGo/SOGo.framework/Versions/Current/sogo:$LD_LIBRARY_PATH"
./obj/sogo-tests 2>/dev/null | tail -3
```

Post-deploy check on the e2e stack (read/write reproduction; artifacts
`test-6143-*` were created and cleaned up during this session — nothing
remains):

```
# 1. session
curl -s -c /tmp/c.txt -X POST -H "Content-Type: application/json" \
  -d '{"userName":"sogo-tests1","password":"sogo"}' http://127.0.0.1:50001/SOGo/connect
# 2. store a card with two WORK phones
printf 'BEGIN:VCARD\r\nVERSION:3.0\r\nN:Doe;John;;;\r\nFN:John Doe\r\nTEL;TYPE=WORK:+1 514 111 2222\r\nTEL;TYPE=WORK:+1 514 333 4444\r\nEND:VCARD\r\n' > /tmp/test-6143.vcf
curl -s -b /tmp/c.txt -X PUT -H "Content-Type: text/vcard" \
  --data-binary @/tmp/test-6143.vcf \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Contacts/personal/test-6143-card.vcf
# 3. export — AVANT: one telephonenumber line; APRÈS: two
curl -s -b /tmp/c.txt -X POST -H "Content-Type: application/json" \
  -d '{"uids":["test-6143-card.vcf"]}' \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Contacts/personal/export
# 4. cleanup
curl -s -b /tmp/c.txt -X DELETE \
  http://127.0.0.1:50001/SOGo/so/sogo-tests1/Contacts/personal/test-6143-card.vcf
```

## PR body draft

When a contact holds several phone numbers of the same type (e.g. two
"Work" numbers), the address book export dropped every number after the
first of its type: the vCard→LDIF conversion behind the web UI export
(`exportAction` → `asLDIFRecord`) resolved each phone key to a single value
via `_simpleValueForType:inArray:excluding:`, which stops at the first
matching `TEL` child. The stored vCard was never affected — the numbers are
all present via CardDAV and in the editor — but any `.ldif` export (single
contact or whole address book) silently lost the extra numbers, and
re-importing that file into another system made the loss permanent.

**AVANT**: a card with `TEL;TYPE=WORK:+1 514 111 2222` and
`TEL;TYPE=WORK:+1 514 333 4444` exports as a single
`telephonenumber: +1 514 111 2222` line; same collapse for repeated
`homephone`/`mobile`/`facsimiletelephonenumber`/`pager` values.

**APRÈS**: `asLDIFRecord` collects every value per phone type (same
matching and FAX-exclusion rules as before, empty values skipped) and the
LDIF writer — which already rendered one line per array element for other
multi-valued attributes — emits one `telephoneNumber:` line per number:
`+1 514 111 2222` and `+1 514 333 4444` both survive the export, and
re-importing the LDIF recreates one `TEL` per line (round-trip covered by
unit tests). LDIF's `telephoneNumber`/`homePhone`/`mobile` are multi-valued
in the Mozilla LDAP schema, so the output stays standards-compliant for
Thunderbird/Outlook imports.
