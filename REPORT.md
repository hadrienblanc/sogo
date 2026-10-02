# Ticket 6161 — NSInvalidArgumentException when an LDAP entry is interpreted as empty

Branch: `fix-6161-mantis` (commit `4632f2de1`), based on `experimental`.

## Root cause (file:line)

The exception chain, matching the attached backtrace exactly:

1. `SoObjects/SOGo/LDAPSource.m:1356-1359` — `_convertLDAPEntryToContact:` computes
   `c_name` from the configured ID field (`_IDField`, e.g. `uid`). When the LDAP entry
   has no value for it, the code falls back to `@""`:
   ```objc
   value = [[ldapEntry attributeWithName: _IDField] stringValueAtIndex: 0];
   if (!value)
     value = @"";
   [ldifRecord setObject: value forKey: @"c_name"];
   ```
   So an entry matched by `mail` during a contact search but lacking the ID attribute
   becomes a contact record whose `c_name`/`id` is the empty string.

2. `SoObjects/Contacts/SOGoContactSourceFolder.m:456-458` (pre-fix numbering) —
   `lookupContactsWithFilter:onCriteria:...` caches every fetched record into the
   `childRecords` dictionary keyed by `c_name`, **including the empty-string key**:
   ```objc
   [childRecords setObjects: records
                   forKeys: [records objectsForKey: @"c_name" notFoundMarker: nil]];
   ```

3. `UI/MailerUI/UIxMailView.m:263` → `SoObjects/Contacts/SOGoContactFolders.m:519` —
   viewing a signed (S/MIME) mail calls `contactForEmail:`, which resolves the matched
   contact by calling `lookupName:` on the source folder with `[contact objectForKey:@"id"]`
   — here `@""`.

4. `SoObjects/Contacts/SOGoContactSourceFolder.m:175-200` — `lookupName:` gets a
   **cache hit** on `childRecords[@""]` and constructs
   `[SOGoContactLDIFEntry contactEntryWithName: @""]`.

5. `SoObjects/Contacts/SOGoContactLDIFEntry.m:55` forwards to
   `SoObjects/SOGo/SOGoObject.m:175-177`, which enforces the SOGoObject invariant:
   ```objc
   if ([_name length] == 0)
     [NSException raise: NSInvalidArgumentException
                  format: @"'_name' must not be an empty string"];
   ```

This is a real bug. The reporter's patch (substituting a dummy name
`"Unnamed Contact"` inside `SOGoContactLDIFEntry initWithName:`) was **not** applied:
a fabricated name is not round-trip-safe — `saveLDIFEntry:`/`deleteLDIFEntry:` use
`nameInContainer` as the LDAP entry ID, so the object would write to a bogus DN, and
two such entries would collide on the same name. The object would also be unreachable
by URL (lookups by `""` do not round-trip). The right place to fix is where the empty
name enters the SOGo object graph.

## What changed (before/after)

`SoObjects/Contacts/SOGoContactSourceFolder.m`, `lookupName:inContext:acquire:` —
3 added lines, immediately after the `super` lookup:

```objc
   obj = [super lookupName: objectName inContext: lookupContext acquire: NO];

+  if (!obj && [objectName length] == 0)
+    obj = [NSException exceptionWithHTTPStatus: 404];
+
   if (!obj)
     {
       ldifEntry = [childRecords objectForKey: objectName];
```

- **AVANT**: an empty `objectName` with a cached empty-keyed record reached
  `SOGoContactLDIFEntry contactEntryWithName:@""` and raised
  `NSInvalidArgumentException: '_name' must not be an empty string`, aborting the
  mail view request (`UIxMailView view:` → 500).
- **APRÈS**: an empty name can never address a child object, so it is answered with
  the same `[NSException exceptionWithHTTPStatus: 404]` used for every other
  unresolved name in this method. `UIxMailView` already filters the result through
  `isKindOfClass:` and simply skips certificate storage; the signed mail renders.
  Non-empty names are strictly unaffected (the guard is checked only when `obj` is
  still nil and the name is empty). The remaining lookup paths were already safe:
  `LDAPSource lookupContactEntry:` refuses empty IDs
  (`LDAPSource.m:1557`), and `SOGoFolder isValidContentName:` rejects empty names
  (`SOGoFolder.m:154`), so the 404 is the uniform outcome for `""`.

## Tests

New `Tests/Unit/TestSOGoContactSourceFolder.m` (registered in `Tests/Unit/GNUmakefile`),
following the `TestSOGoFolderSubscriptionRoles` pattern (runtime bundle load via
`loadSOGoBundle:markerClass:`, no compile-time link against the Contacts bundle):

- `test_lookupNameWithEmptyNameReturnsHTTP404` — seeds `childRecords[@""]` (via KVC on
  the ivar) to replay the ticket's cache state, then asserts `lookupName:@""` returns
  an `NSException` with `httpStatus == 404` instead of raising.
- `test_lookupNameWithUnknownNameReturnsHTTP404` — locks the pre-existing miss path
  (unknown non-empty name → HTTP 404) that the new guard mirrors.

Regression proof (fix temporarily reverted, suite rebuilt):

```
ERROR: test_lookupNameWithEmptyNameReturnsHTTP404
an exception occured: NSInvalidArgumentException
  reason: '_name' must not be an empty string
```

With the fix restored the test passes — it reproduces the exact ticket exception.

## Verification steps for the orchestrator

```
# full unit suite (only known host-noise failures: test_NGInternetSocketAddressFromString,
# test_stringWithoutHTMLInjection)
/home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
  /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c12-6161
# expected: Ran 147 tests — FAILED (2 failures, 0 errors), the 2 documented host-noise ones

# targeted check that the new tests ran green (must run from Tests/Unit for bundle paths)
cd /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c12-6161/Tests/Unit
source /home/hadrienblanc/Projets/hadrienblanc/sogo/local/env.sh
export LD_LIBRARY_PATH="/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c12-6161/SOPE/NGCards/obj:/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c12-6161/SOPE/GDLContentStore/obj:/home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c12-6161/SoObjects/SOGo/SOGo.framework/Versions/Current/sogo:$LD_LIBRARY_PATH"
./obj/sogo-tests -f junit 2>/dev/null | grep -A3 lookupNameWith
# expected: both testcases empty (passing), no <failure>/<error>
```

Note on e2e: the shared stack has no LDAP source configured (SQL address books only),
and the fix is not deployed to it (deploys are orchestrator-only), so the LDAP path is
not reproducible there read-only; the unit test replays the exact crash state instead.
No `test-6161-*` artifacts were created on the stack.

## PR body draft

When a LDAP directory contains an entry that matches a contact search (e.g. by
`mail`) but has no value for the configured ID field (`UIDField`/`IDField`, e.g.
`uid`), SOGo's LDAP source turns it into a contact record with an empty `c_name`
(`LDAPSource.m`). `SOGoContactSourceFolder lookupContactsWithFilter:` then caches that
record under the empty-string key in its `childRecords` cache. When such an address
book is consulted while viewing a signed (S/MIME) mail — `UIxMailView` →
`SOGoContactFolders contactForEmail:` — the folder receives `lookupName: @""`, gets a
cache hit, and tries to build `SOGoContactLDIFEntry contactEntryWithName: @""`, which
violates `SOGoObject`'s non-empty-name invariant and raises:

```
EXCEPTION: NSInvalidArgumentException REASON: '_name' must not be an empty string
```

The request aborts and the signed mail cannot be displayed. An empty name can never
address a child object: the LDAP and SQL sources already refuse to resolve empty IDs
and `isValidContentName:` rejects empty names, so the only remaining entry point was
the `childRecords` cache hit. `SOGoContactSourceFolder lookupName:` now answers an
empty name with the standard HTTP 404 exception, exactly like any other unresolved
name — callers already handle it (`isKindOfClass:` checks), so the mail view renders
normally and simply skips storing a certificate for a contact that cannot be
represented. The workaround proposed in the ticket (a dummy "Unnamed Contact" name
inside `SOGoContactLDIFEntry`) was deliberately not used: a fabricated name is not
round-trip-safe against the LDAP directory (save/delete would target a bogus ID) and
the object would remain unreachable by URL.
