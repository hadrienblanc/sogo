# Ticket 6179 — CardDAV shared read-only address books: empty `current-user-privilege-set`

Branch: `fix-6179-mantis` — commit `954ed35d2`
Verdict: **confirmed bug**, fixed.

## Root cause

- `SoObjects/SOGo/SOGoGCSFolder.m:87-94` (`+webdavAclManager`): the registration of the
  `{DAV:}read` and `{DAV:}read-current-user-privilege-set` privileges has been **commented
  out since the file was created**. The GCS ACL tree therefore only contains write/admin
  privileges.
- `SOGoContactGCSFolder` (CardDAV address books) does not override `webdavAclManager`, so
  `davCurrentUserPrivilegeSet` (`SoObjects/SOGo/SOGoObject.m:447-457`) walks a tree with no
  `read` node. Any user whose roles do not imply a write permission (i.e. a read-only
  subscriber with role `ObjectViewer`) gets **zero** privileges, and even owners never see
  `{DAV:}read`.
- Calendars are unaffected because `SOGoAppointmentFolder.m:107` has its own manager that
  registers `{DAV:}read` → `SoPerm_WebDAVAccess` (which is why shared read-only calendars
  are discoverable in Thunderbird while address books are not).

Reproduced on the e2e stack (before fix):

- `MKCOL /SOGo/dav/sogo-tests1/Contacts/test-6179-ab/` as sogo-tests1, share
  `ObjectViewer` to sogo-tests2 (inverse-dav `acl-query`/`set-roles`, 204).
- `PROPFIND` `current-user-privilege-set` as sogo-tests2 →
  `<D:current-user-privilege-set xmlns:D="DAV:"></D:current-user-privilege-set>` (empty),
  exactly the ticket's "bad" response. The equivalent read-only calendar returns
  `<D:read/>` + `<D:read-current-user-privilege-set/>`.

## What changed

- `SoObjects/SOGo/SOGoGCSFolder.m` — reinstated (uncommented) the two registrations in the
  GCS folder ACL tree, identical semantics to `SOGoAppointmentFolder`'s manager:
  - `{DAV:}read` (abstract, equivalent `SoPerm_WebDAVAccess`, child of `{DAV:}all`)
  - `{DAV:}read-current-user-privilege-set` (abstract, equivalent `SoPerm_WebDAVAccess`,
    child of `{DAV:}read`)

The manager is only consumed for privilege *reporting* (`current-user-privilege-set`,
`supported-privilege-set`, and `grant` ACEs of the ACL REPORT), so no permission checking
behavior changes; roles that hold "WebDAV Access" (`ObjectViewer`, `ObjectEditor`, owner,
…) are now simply advertised `DAV:read`.

### AVANT (read-only subscriber, PROPFIND as sogo-tests2)

```xml
<D:current-user-privilege-set xmlns:D="DAV:"></D:current-user-privilege-set>
```

### APRÈS

```xml
<D:current-user-privilege-set xmlns:D="DAV:">
  <D:privilege><D:read/></D:privilege>
  <D:privilege><D:read-current-user-privilege-set/></D:privilege>
</D:current-user-privilege-set>
```

(Owner additionally keeps write/bind/unbind/write-properties/write-content/read-acl/
write-acl/admin/all, and now also `read` + `read-current-user-privilege-set`, as for
calendars.)

## Tests

- `Tests/Unit/TestSOGoWebDAVAclManager.m` (registered in `Tests/Unit/GNUmakefile`):
  - `test_gcsFolderDavPrivilegesIncludeRead` — asserts `{DAV:}read` and
    `{DAV:}read-current-user-privilege-set` are produced by
    `[SOGoGCSFolder webdavAclManager] davPermissionsForRoles:onObject:`. **Fails on the
    unfixed tree** (verified by stashing the fix), passes with it.
  - `test_gcsFolderDavPrivilegesIncludeWriteForWriters` — guards the pre-existing write
    privileges still being reported.
- `Tests/spec/CardDAVPrivilegeSetSpec.js` (e2e, needs the stack): read-only subscriber
  (`ObjectViewer`) gets `read` + `readCurrentUserPrivilegeSet` and no `write`; owner gets
  both `read` and `write`.

Unit suite: `local/run-worktree-tests.sh wt/c12-6179` → 128 tests, only the two known
host-noise failures (`test_NGInternetSocketAddressFromString`,
`test_stringWithoutHTMLInjection`).

## Verification steps for the orchestrator

After the fix is deployed on the e2e stack (deploys are orchestrator-only):

```bash
# setup: read-only share
curl -s -o /dev/null -w "%{http_code}\n" -u sogo-tests1:sogo -X MKCOL \
  http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Contacts/test-6179-ab/
curl -s -o /dev/null -w "%{http_code}\n" -u sogo-tests1:sogo -X POST \
  -H "Content-Type: application/xml; charset=utf-8" \
  --data '<?xml version="1.0"?><acl-query xmlns="urn:inverse:params:xml:ns:inverse-dav"><set-roles user="sogo-tests2"><ObjectViewer/></set-roles></acl-query>' \
  http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Contacts/test-6179-ab/

# subscriber PROPFIND must now contain <D:privilege><D:read/></D:privilege>
curl -s -u sogo-tests2:sogo -X PROPFIND -H "Depth: 0" -H "Content-Type: application/xml" \
  --data '<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop><D:current-user-privilege-set/></D:prop></D:propfind>' \
  http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Contacts/test-6179-ab/

# cleanup
curl -s -o /dev/null -w "%{http_code}\n" -u sogo-tests-super:sogo -X DELETE \
  http://127.0.0.1:50001/SOGo/dav/sogo-tests1/Contacts/test-6179-ab/
```

Expected: `current-user-privilege-set` contains `<D:read/>` and
`<D:read-current-user-privilege-set/>` (previously empty — see AVANT/APRÈS above).
The e2e suite should also run `CardDAVPrivilegeSetSpec.js`
(`npx jasmine --filter "current-user-privilege-set on address books (bug 6179) read-only subscriber gets the DAV read privilege"`).

## PR body draft

> ### CardDAV: shared read-only address books reported an empty `current-user-privilege-set` (bug 6179)
>
> **Context.** SOGo's WebDAV ACL manager builds `current-user-privilege-set` by walking a
> per-class DAV privilege tree. For GCS folders (the base of every CardDAV address book)
> the `{DAV:}read` and `{DAV:}read-current-user-privilege-set` registrations had been
> commented out since the tree was introduced, while calendars
> (`SOGoAppointmentFolder`) always registered them. As a result, a user with read-only
> access to a shared address book received an empty
> `<D:current-user-privilege-set/>` in discovery PROPFINDs — owners never saw
> `{DAV:}read` either. Thunderbird 148 requires the `read` privilege (or the absence of
> the property) before listing an address book as addable, so read-only shared address
> books could not be subscribed to ("No address books found"), although they work fine
> once forced.
>
> **Change.** This PR reinstates the two registrations in
> `+[SOGoGCSFolder webdavAclManager]` with the same semantics as the calendar manager
> (`read` and `read-current-user-privilege-set`, both mapped to the `WebDAV Access`
> permission). The DAV *avant* for a read-only subscriber was
> `<D:current-user-privilege-set xmlns:D="DAV:"/>`; *après* it is
> `<D:privilege><D:read/></D:privilege><D:privilege><D:read-current-user-privilege-set/></D:privilege>`,
> matching what SOGo already returns for read-only shared calendars. Only privilege
> reporting is affected (no ACL enforcement change). Covered by a new unit test locking
> the GCS tree registration and a new e2e spec (`CardDAVPrivilegeSetSpec`) checking the
> subscriber and owner PROPFIND responses.
