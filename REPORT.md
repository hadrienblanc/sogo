# Ticket 6144 — DAV client: shared email alias attributes the event to the wrong user ("visible in SOGo" aliases)

Branch: `fix-6144-mantis` (worktree `wt/c13-6144`)

## Root cause (file:line)

When several mailboxes publish the same email address in the authentication
source (an alias with the "visible in SOGo" option — i.e. the address ends up
in each account's mail fields / `emails` list), SOGo's reverse resolution
**email → user** returns an arbitrary account:

- `SoObjects/SOGo/SOGoUserManager.m:962` (`_fillContactInfosForUser:`) — the
  source lookup `lookupContactEntryWithUIDorEmail:` matches the first entry
  whose `mail`/alias field equals the address (SQL: first row of
  `c_uid = X OR mail = X OR <mailFields> = X`; LDAP: first entry of
  `(|(uid=X)(mail=X)...)`). With N accounts sharing the alias, the winner is
  database/directory order — "it could be any user which has the same alias".
- `SoObjects/SOGo/SOGoUserManager.m:1040` (`_retainUser:withLogin:`) — every
  user entry is additionally cached in memcached under **each** of the user's
  emails, so the cache entry for the shared alias flips between accounts
  depending on who logged in / was resolved last.

The calendar scheduling code, however, decides identity with
`-[SOGoUser hasEmail:]` (`userIsOrganizer:`, `userIsAttendee:`,
`userAsAttendee:` in `SoObjects/Appointments/iCalEntityObject+SOGo.m:441-513`)
— for the current user that answer is unambiguous. The defect sits in the two
spots that used the ambiguous directory lookup instead:

- `SoObjects/Appointments/iCalEntityObject+SOGo.m:594`
  (`attendeesWithoutUser:`) — compared the *resolved uid* of each attendee to
  the owner's login. A DAV client that includes the organizer's address in the
  attendee list (Thunderbird/Outlook do) with a shared alias resolved the entry
  to some *other* mailbox, so the entry was **not** filtered out: the invite
  flow then treated that arbitrary account as a real attendee — freebusy
  conflict checks against the wrong calendar and an event copy filed into the
  wrong user's calendar (`_addOrUpdateEvent:forUID:`).
- `SoObjects/Appointments/iCalPerson+SOGo.m:59-78` (`uid`, `uidInContext:`) —
  the organizer/attendee→uid resolution handed to the UI
  (`attributesInContext:` → `organizer.uid`, used for freebusy lookups) and to
  the scheduling paths (`_handleAttendeesConflicts`, `_handleAttendee`,
  `_updateAttendee:` …) returned the arbitrary account: the "creator" shown
  and acted upon was not the own user.

## What changed (before/after)

### `SoObjects/Appointments/iCalPerson+SOGo.h/.m`

New `- (NSString *) uidForUser: (SOGoUser *) user`: if the given user owns the
person's email address (`hasEmail:`, aliases included), return that user's
login; otherwise fall back to the unchanged directory lookup (`uid`).

`uidInContext:` now applies the same preference for the **active user** before
falling back to `uidInDomain:`.

**Before** (organizer = shared alias `team@example.org`, active user
`mailbox-one` who owns that alias, `mailbox-two` owns it too):

```
[[event organizer] uidInContext: context]  →  @"mailbox-two"   (arbitrary: cache/directory order)
```

**After**:

```
[[event organizer] uidInContext: context]  →  @"mailbox-one"   (deterministic: the acting user owns the address)
```

When the acting user does *not* own the address, the previous lookup is used
unchanged — no behavior change for unambiguous addresses.

### `SoObjects/Appointments/iCalEntityObject+SOGo.m`

- `attendeesWithoutUser:` drops an attendee not only when its resolved uid
  equals the user's login (unchanged) but **also when the user owns the
  attendee's email** — making it consistent with `userIsOrganizer:` /
  `userAsAttendee:` / `userIsAttendee:`, which are all email-based. Before: an
  attendee entry `mailto:team@example.org` belonging to the owner via a shared
  alias stayed in the list and was scheduled as another mailbox; after: it is
  recognized as the owner themself.
- `attributesInContext:` resolves the exposed `organizer.uid` through
  `uidForUser: [context activeUser]` instead of the raw directory lookup, so
  the creator/organizer identity served to the web UI is the acting user
  whenever they own the organizer address (nil-context safe: falls back to the
  previous behavior).

The write paths in `SOGoAppointmentObject.m` are not touched; they become
correct through `uidInContext:`/`attendeesWithoutUser:`
(`_handleAttendeesConflicts`, `_handleSequenceUpdateInEvent`,
`_handleUpdatedEvent`, `_handleAttendee`/`_updateAttendee`,
`saveComponent:`, `updateContentWithCalendar:`).

## Tests

New `Tests/Unit/TestiCalPerson+SOGo.m` (registered in `Tests/Unit/GNUmakefile`),
using a stub `SOGoUser` subclass (fixed `allEmails` = primary address + shared
`test-6144-alias@example.org`, `trust:YES` init so no source is needed) and a
real `WOContext` with `setActiveUser:`:

- `test_uidForUserPrefersUserOwningTheAlias` — exact ticket scenario at the
  resolution level: shared alias resolves to the owning user.
- `test_uidForUserFallsBackOnForeignEmail` — foreign address never resolves to
  the user; equals the plain directory lookup.
- `test_uidInContextResolvesOwnAliasToActiveUser` /
  `test_uidInContextIgnoresForeignEmail` — both branches of `uidInContext:`.
- `test_attendeesWithoutUserDropsAttendeeWithOwnAlias` — the DAV PUT scenario:
  the organizer-as-attendee alias entry is filtered out, the real guest stays.
- `test_attendeesWithoutUserKeepsForeignAttendees` — unrelated attendees are
  kept (no over-filtering).
- `test_attributesExposeOrganizerUidOfActiveUser` — the API payload exposes
  `organizer.uid` = the acting user for their own alias.
- `test_attributesOmitOrganizerUidWithoutOwner` — nil-context/foreign fallback:
  no `uid` key, previous behavior preserved.

Full suite: `Ran 165 tests — FAILED (2 failures)`, the 2 being the known
host-noise `test_NGInternetSocketAddressFromString` and
`test_stringWithoutHTMLInjection`. (The test binary also segfaults during the
final autorelease-pool drain of `main` on this host; that crash reproduces on
the **untouched baseline** of this worktree and on other worktrees' binaries,
after the summary is printed — pre-existing host noise, unrelated to this
change.)

Live repro on the e2e stack was not possible read-only: the stack's LDAP has
no shared alias between `sogo-tests1/2/3` and adding one would require
container/config changes (orchestrator-only). The unit tests encode the
scenario at the exact resolution seam instead.

## Verification steps for the orchestrator

```
# full unit suite (build + run; 165 tests, only the 2 known host-noise failures)
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c13-6144
# expected last lines:
#   Ran 165 tests
#   FAILED (2 failures, 0 errors)
# (exit status 139 of the runner is the pre-existing pool-drain segfault at
#  process exit — also present on a clean checkout; judge by the summary)

# eyeball the new tests specifically (157 -> 165 tests when the file is added;
# failures stay at the 2 known ones):
cd /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c13-6144/Tests/Unit
source /home/hadrienblanc/Projets/hadrienblanc/sogo/local/env.sh
export LD_LIBRARY_PATH="../SOPE/NGCards/obj:../SOPE/GDLContentStore/obj:../SoObjects/SOGo/SOGo.framework/Versions/Current/sogo:$LD_LIBRARY_PATH"
./obj/sogo-tests 2>/dev/null | tail -3
```

Post-deploy check on the e2e stack (needs two users sharing an alias in the
source, e.g. both listing `team@example.org`): CalDAV-PUT a new VEVENT with
`ORGANIZER:mailto:team@example.org` and `ATTENDEE:mailto:team@example.org`
(Thunderbird-style self-attendee) into user A's calendar, then verify in the
web UI that the event's organizer resolves to A and that no copy of the event
appears in user B's calendar.

## PR body draft

When an email alias is published to SOGo from several mailboxes ("visible in
SOGo"), the reverse resolution from an email address to a user account is
ambiguous: the authentication sources return the first entry matching the
address, and the memcached email→user mapping is overwritten by whichever
account was resolved last. Calendar scheduling and the web UI therefore
attributed events to an arbitrary account sharing the address: after a DAV
client created an appointment whose organizer (or self-attendee entry) used
the alias, SOGo could file attendee copies into another mailbox's calendar,
run freebusy checks against the wrong user, and expose a wrong
`organizer.uid` — "the creator of the appointment is not the own user as it
should be, it could be any user which has the same alias".

**AVANT**: `ORGANIZER;CN=A:mailto:team@example.org` +
`ATTENDEE:mailto:team@example.org` PUT via CalDAV by `mailbox-one` →
`[attendee uidInContext:]` resolves the alias to `mailbox-two` (directory/cache
order) → the alias entry is *not* filtered by `attendeesWithoutUser:`;
`mailbox-two` is treated as a distinct attendee: conflict check against
`mailbox-two`'s freebusy, event copy saved into `mailbox-two`'s calendar, and
the UI's `organizer.uid` points at `mailbox-two` — the creator shown is any of
the alias holders, varying over time with the cache.

**APRÈS**: identity resolution prefers the user that actually owns the
address: `uidInContext:`/`uidForUser:` return the acting user's login whenever
`hasEmail:` matches (aliases included), and `attendeesWithoutUser:` drops
attendee entries whose address belongs to the owner — consistent with the
pre-existing email-based `userIsOrganizer:`/`userAsAttendee:` semantics. The
creator/organizer resolves to the own user deterministically, no spurious
copies land in other alias holders' calendars, and unambiguous addresses keep
the exact previous behavior (foreign emails fall back to the unchanged
directory lookup; covered by unit tests on `iCalPerson` and
`attendeesWithoutUser:`).
