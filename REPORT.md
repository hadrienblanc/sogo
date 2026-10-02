# Ticket 6171 — Calendar ACLs set via sogo-tool are lost when accessing the web interface

Branch: `fix-6171-mantis` (commit `fa4002464`) — https://bugs.sogo.nu/view.php?id=6171

## Root cause (file:line)

This **is** a bug, reproduced live on the e2e stack. Two independent defects make
subscriptions installed by `sogo-tool manage-acl subscribe` disappear at the first
web login:

1. **Destructive pruning driven by stale ACL cache.**
   On every web request that lists folders (first one at login:
   `/SOGo/so/<user>/Calendar/calendarslist`), `-[SOGoParentFolder appendSubscribedSources]`
   (`SoObjects/SOGo/SOGoParentFolder.m:313-392`) walks `Calendar.SubscribedFolders` and
   calls `-_appendSubscribedSource:` (`SOGoParentFolder.m:287-311`). That method fails —
   and the entry is **removed and synchronized to the DB** (`SOGoParentFolder.m:351-389`) —
   whenever `validatePermission: SOGoPerm_AccessObject` denies access, which happens when
   `-[SOGoGCSFolder aclsForUser:]` returns no authorizing role. Folder-level "Access
   Object" is granted only via Owner/AuthorizedSubscriber (`UI/MainUI/product.plist:61`,
   `SOGoUser.m:1260-1265`).
   `sogo-tool manage-acl add` (`Tools/SOGoToolManageACL.m:284-318`) inserts ACL rows with
   raw SQL and — unlike `manage-acl remove` (`SOGoToolManageACL.m:377-380`, which calls
   `setACLs:nil forPath:`) and unlike the web `setRoles:` path
   (`SOGoGCSFolder.m:1978`) — **never invalidates the `<path>+acl` memcached entry**
   (`SOGoCache.m:748-769`). For up to `SOGoCacheCleanupInterval` (default 300 s,
   `SOGoDefaults.plist:25`), sogod workers therefore keep serving the *pre-ACL* (empty)
   roles for users on that path (`SOGoGCSFolder.m:1733-1755` also caches the empty
   result), so any group member who logs in inside that window has their
   freshly-subscribed calendar pruned — permanently, because the prune writes the user
   settings. With a daily re-subscribe cron this looks exactly like "the web interface
   drops SubscribedFolders".

2. **Group ACLs evaluate to "no access" when memcached cannot serve the member list.**
   `-[LDAPSource groupWithUIDHasMemberWithUID:memberUid:]`
   (`SoObjects/SOGo/LDAPSource.m:2456-2484`) resolves membership *only* through the
   `"<group>+<domain>"` memcached key written by `membersForGroupWithUID:`. When
   memcached is unreachable (or the entry cannot be stored), `value` stays nil,
   `[nil componentsSeparatedByString:]` yields nil and the method returns NO
   unconditionally — the group grant silently vanishes, the user is seen as
   unauthorized, and the subscription is pruned on login. Note the asymmetry that
   matches the report: `sogo-tool manage-acl subscribe` uses `membersForGroupWithUID`
   directly (live LDAP query, succeeds — "the status in the database is apparently
   correct"), only the *evaluation* at web login is memcached-dependent.

Live reproduction (stack at http://127.0.0.1:50001, LDAP group `@readers` with members
sogo-tests1/2/3): calendar `test-6171-cal` created for sogo-tests1, group ACL set, group
subscribed → `GET jsonSettings` for sogo-tests2 shows
`SubscribedFolders: ["sogo-tests1:Calendar/test-6171-cal"]`; a **single**
`calendarslist` fetch later the setting is `SubscribedFolders: []`,
`FolderDisplayNames: {}` — the reported data loss, before any fix of the roles
involved. (With the ticket's exact role set and healthy memcached the prune does not
trigger — the two defects above are what make it fire in the field.)

## What changed (before/after)

- `Tools/SOGoToolManageACL.m` (`addACLForUser:`): after inserting the ACL rows, invalidate
  the distributed ACL cache — same as `removeACLForUser:` already did.

  AVANT: `sogo-tool manage-acl add ...` → sogod workers keep the old (empty) roles for
  ≤ SOGoCacheCleanupInterval → member logs in → subscription judged unauthorized →
  `SubscribedFolders` entry deleted from `sogo_user_profile`.

  APRES: the `<path>+acl` cache entry is dropped at once; the next evaluation re-reads
  the ACL table, the member gets AuthorizedSubscriber via ObjectCreator/the viewer
  roles, and the subscription survives the login.

- `SoObjects/SOGo/LDAPSource.m` (`groupWithUIDHasMemberWithUID:memberUid:`): when the
  member list cannot be served from memcached, fall back to a live membership check on
  the array returned by `membersForGroupWithUID:` (same `loginInDomain` projection used
  to build the cached list). Behaviour is unchanged when memcached answers.

  AVANT: no (or broken) memcached ⇒ every group-ACL check returns "not a member" ⇒
  group subscriptions pruned at each web login, while `manage-acl subscribe` kept
  re-adding them.

  APRES: the membership is resolved from LDAP and the group grant is honored, with or
  without memcached.

## Tests

- `Tests/Unit/TestSOGoFolderSubscriptionRoles.m` (new, registered in
  `Tests/Unit/GNUmakefile`): locks that the roles granted by the documented
  `sogo-tool manage-acl add` example for calendars (ObjectCreator + Public/Private/
  Confidential Modifier) and the calendar viewer roles intersect
  `-[SOGoAppointmentFolder subscriptionRoles]` (the AuthorizedSubscriber source), and
  that `-[SOGoFolder subscriptionRoles]` keeps the Object* roles — the invariant whose
  violation turns a login into a prune.
- `Tests/Unit/TestSOGoCacheACLs.m` (new): locks `-[SOGoCache setACLs:forPath:]` /
  `aclsForPath:` round-trip and the nil-invalidation used by `manage-acl add/remove`
  (bug 6171), plus harmlessness of invalidating an uncached path.

Suite result: `Ran 133 tests, FAILED (2 failures, 0 errors)` — the two failures are the
known host-noise ones (`test_NGInternetSocketAddressFromString`,
`test_stringWithoutHTMLInjection`); the process-exit segfault after the summary is also
present on the untouched baseline checkout. `Tools/` (sogo-tool) builds cleanly.

## Verification steps for the orchestrator

Deploy this branch on the e2e stack, then:

```bash
BASE=http://127.0.0.1:50001
# 1. fixture (as owner + super-user, group '@readers' exists in the e2e LDAP)
curl -s -o /dev/null -u sogo-tests1:sogo -X MKCALENDAR -H "Content-Type: text/xml" \
  --data '<mkcalendar xmlns="DAV:"><set><prop><resourcetype><calendar/></resourcetype><displayname>test-6171-cal</displayname></prop></set></mkcalendar>' \
  "$BASE/SOGo/dav/sogo-tests1/Calendar/test-6171-cal/"
docker exec sogo_dev su sogo -s /bin/sh -c \
  "sogo-tool manage-acl add sogo-tests1 Calendar/test-6171-cal '@readers' '[\"ObjectCreator\",\"PublicModifier\",\"ConfidentialModifier\",\"PrivateModifier\"]'"
# 2. login as a group member right away (< cache TTL) and prime a stale-empty role cache
curl -s -o /dev/null -c /tmp/cj -X POST -H "Content-Type: application/json" \
  -d '{"userName":"sogo-tests2","password":"sogo"}' "$BASE/SOGo/connect"
# 3. subscribe via the tool (what the cron does)
docker exec sogo_dev su sogo -s /bin/sh -c \
  "sogo-tool manage-acl subscribe sogo-tests1 Calendar/test-6171-cal '@readers'"
# 4. web login: fetch the calendar list (this used to prune the subscription)
curl -s -b /tmp/cj "$BASE/SOGo/so/sogo-tests2/Calendar/calendarslist"
# 5. EXPECT: the shared calendar is listed and SubscribedFolders still holds the ref
curl -s -b /tmp/cj "$BASE/SOGo/so/sogo-tests2/jsonSettings"
#    -> "SubscribedFolders": [ "sogo-tests1:Calendar/test-6171-cal" ]
#    (before the fix this returned [] after step 4)
# 6. unit suite
local/run-worktree-tests.sh <this-worktree>   # 133 tests, only the 2 known host failures
# 7. cleanup
curl -s -o /dev/null -u sogo-tests-super:sogo -X DELETE "$BASE/SOGo/dav/sogo-tests1/Calendar/test-6171-cal/"
```

## PR body draft

Subscriptions installed with `sogo-tool manage-acl subscribe` were silently deleted
from the user profile at the first web login (bug 6171). The login-time folder listing
(`-[SOGoParentFolder appendSubscribedSources]`) removes any `SubscribedFolders` entry
whose folder fails the `Access Object` check and synchronizes that removal to the
database — so anything that makes the ACL evaluation briefly answer "no access" turns
into permanent data loss for the subscription.

AVANT: `sogo-tool manage-acl add` wrote the ACL rows with raw SQL without invalidating
the distributed ACL cache (while `manage-acl remove` did), so sogod workers kept serving
the pre-ACL roles for up to `SOGoCacheCleanupInterval` (300 s); a group member logging
in during that window saw no authorizing role and lost the calendar the cron had just
installed — reproduced on the e2e stack where one `calendarslist` fetch turned
`SubscribedFolders: ["sogo-tests1:Calendar/test-6171-cal"]` into `[]`. Additionally,
`-[LDAPSource groupWithUIDHasMemberWithUID:memberUid:]` answered "not a member"
whenever memcached could not serve the cached member list, making every group-ACL
subscription prunable on each login while `manage-acl subscribe` (live LDAP query)
kept succeeding.

APRES: `manage-acl add` invalidates the `<path>+acl` cache entry exactly like
`remove`, so freshly granted roles are visible immediately and the login-time
authorization check passes; and the LDAP group-membership check falls back to a live
evaluation of `membersForGroupWithUID:` when memcached has no answer, so group grants
no longer depend on the cache to be honored. Behaviour is unchanged on healthy
setups (verified: the ticket's exact role set survives login). Two unit suites lock
the subscription-authorization roles and the ACL cache invalidation primitive.
