# Fix 6251 — VLIST does not permanently save the selected email address of contacts with multiple addresses

Ticket: https://bugs.sogo.nu/view.php?id=6251 (severity minor, Web Address Book, 5.12.11)
Branch: `fix-6251-mantis`

## Verdict

This **is a bug**, reproduced live on the e2e stack (see Verification). A VLIST
member *does* store an `EMAIL` attribute on its `CARD` line (`CARD;FN=...;EMAIL=...:<uid>`),
and all consumers (list view `data`/`properties` actions, LDIF export, mail
composition in `UIxMailMainFrame`) use that stored value — but the list editor
never wrote the user's selection into it, and never updated it.

## Root cause (file:line)

Three cooperating defects, all on the save path of the list editor:

1. **`UI/Contacts/UIxListEditor.m` (old lines 233–237 and 245–249, `-setReferences:`)** —
   when a member is added, the server ignores the email selected by the user and
   stores `[emails objectAtIndex: 0]`, the first entry of the contact's quick-table
   `c_mail` field. That order is the indexer's "preferred" order and does not even
   follow the vCard order (observed reversed on the e2e stack: vCard `home,work`
   was indexed as `c_mail=work,home`), so the stored address is routinely not the
   one picked in the autocomplete (`Card.prototype.$preferredEmail(partial)` in
   `Card.service.js` matches the *typed text* against the addresses).

2. **`UI/Contacts/UIxListEditor.m` (old line 201, `// TODO: update existing cards?`)** —
   when a member is already in the list (`cardReferences:contain:` → YES, e.g. the
   user removed and re-added the contact with another address selected in the same
   edit session), nothing is updated. Re-selecting an address and re-saving could
   therefore never persist — exactly the "Changing the address again and saving
   the list does not persist the selection" part of the ticket.

3. **`UI/WebServerResources/js/Contacts/Card.service.js` (`Card.prototype.$save`, line ~277)** —
   the selected address lives in `ref.$$email` on the client, but `$omit()` drops
   every `$`-prefixed key, so the payload never carried the selection to the server.

Supporting fact: the persistence layer itself was already fine — `NGVCardReference`
keeps `EMAIL` as an attribute and all readers use it; the LDIF import path
(`NGVList+SOGo.m setCardReference:inContainer:`, line 186) already honors the
member's `mail`. Only the web editor path was broken.

## What changed (before/after)

- `SOPE/NGCards/NGVList.h/.m` — new accessor `-cardReferenceForReference:`
  (NGVList.m:192), the lookup counterpart of the existing `deleteCardReference:`.

- `UI/Contacts/UIxListEditor.m` `-setReferences:` (lines 223–258) —
  - BEFORE: existing member → skipped entirely (`TODO: update existing cards?`);
    new member → `EMAIL` forced to the first address of `c_mail`.
  - AFTER: the client-provided `email` of the member dict is validated
    (`NSString`, non-empty) into `memberEmail`; if the member already exists, its
    stored `EMAIL` is refreshed with `memberEmail` (implements the old TODO);
    when adding (both the personal-folder branch and the public/shared-AB branch),
    `memberEmail` wins and only falls back to the first address of `c_mail` when
    the client sent none. The new-contact fallback branch is untouched.

- `UI/WebServerResources/js/Contacts/Card.service.js` (`$save`, line 280) —
  - BEFORE: only `ref.reference = ref.id` was set; the selection (`ref.$$email`)
    was dropped by `$omit()` and never sent.
  - AFTER: `ref.email = ref.$$email` is also set, so the payload carries the
    address the user picked in the members autocomplete (for members reloaded
    from a list, `$$email` is the stored address, making the save a no-op as before).

### AVANT (reproduced on the unfixed stack, SOGo 5.12.x)

```
Contact: test-6251-john.vcf  (EMAIL home: john.private@…, EMAIL work: board@…)
c_mail (quick table): "board@example.com,john.private@example.com"

POST saveAsList  refs[0].email = "john.private@example.com"   ← user selection
→ stored: CARD;EMAIL=board@example.com;FN=John Doe:test-6251-john.vcf   ✗
POST saveAsList  refs[0].email = "board@example.com"          ← user re-selects
→ stored: CARD;EMAIL=board@example.com;…                               (no-op)
POST saveAsList  refs[0].email = "john.private@example.com"   ← tries again
→ stored: CARD;EMAIL=board@example.com;…                               ✗ forever
```

### APRÈS (with this fix)

```
POST saveAsList  refs[0].email = "john.private@example.com"
→ stored: CARD;EMAIL=john.private@example.com;FN=John Doe:john.vcf      ✓
POST saveAsList  refs[0].email = "board@example.com"
→ stored: CARD;EMAIL=board@example.com;FN=John Doe:john.vcf             ✓
```

Two lists may now reference the same contact through different addresses
("Invitations" → john.private@, "Internal" → board@), as requested in the ticket.

## Tests

- `Tests/Unit/TestNGVList.m` (new, registered in `Tests/Unit/GNUmakefile`):
  - `test_cardReferenceForReference` — lookup hits/misses over several members;
  - `test_selectedEmailRoundTrip` — VLIST `CARD;EMAIL=…` survives parse → render →
    parse, and an updated selection (`setEmail:`) persists through the round-trip;
  - `test_deleteCardReferenceKeepsOthers` — deletion keeps the other members and
    their emails intact.
- `Tests/spec/HTTPListMembersSpec.js` (new e2e, auto-discovered by jasmine): creates
  a two-email contact and a VLIST over CardDAV, then locks the three behaviors —
  selected work address stored, non-default (private) address stored, and update of
  an existing member's address on re-save.
- Unit suite: **252 tests, OK** (`local/run-worktree-tests.sh`), including the 3 new
  tests (the known host-noise failures did not trigger on this run).
- The e2e spec cannot pass on the shared stack until the orchestrator redeploys
  this branch (deploys are orchestrator-only); against the unfixed stack it fails
  exactly on the reproduced behaviors above.

## Verification steps for the orchestrator

1. Unit suite (already green in this worktree):

   ```
   /home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
     /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c35-6251
   ```

2. After the next stack rebuild/merge, e2e (inside the `sogo_dev` container):

   ```
   cd /workspace/Tests && sed -i 's/port: "50001"/port: "50000"/' lib/config.js && \
   npx jasmine --config=spec/support/jasmine.json --filter="HTTP Contacts list members" && \
   sed -i 's/port: "50000"/port: "50001"/' lib/config.js
   ```

3. Manual curl check against a stack running this branch (artifacts prefixed
   `test-6251-`, delete afterwards):

   ```
   u=sogo-tests1:sogo; base=http://127.0.0.1:50001
   curl -s -u $u -X PUT -H "Content-Type: text/vcard" --data-binary \
     $'BEGIN:VCARD\r\nVERSION:3.0\r\nUID:test-6251-john\r\nFN:John Doe\r\nEMAIL;TYPE=home:john.private@example.com\r\nEMAIL;TYPE=work:board@example.com\r\nEND:VCARD\r\n' \
     "$base/SOGo/dav/sogo-tests1/Contacts/personal/test-6251-john.vcf"
   curl -s -u $u -X PUT -H "Content-Type: text/vcard" --data-binary \
     $'BEGIN:VLIST\r\nUID:test-6251-list.vcf\r\nVERSION:1.0\r\nFN:List 6251\r\nEND:VLIST\r\n' \
     "$base/SOGo/dav/sogo-tests1/Contacts/personal/test-6251-list.vcf"
   # session cookie for UI actions
   curl -s -c /tmp/opencode/test-6251-cookies.txt -X POST -H "Content-Type: application/json" \
     -d '{"userName":"sogo-tests1","password":"sogo"}' "$base/SOGo/connect" -o /dev/null
   # save with the private address selected, then read back the stored CARD line
   curl -s -b /tmp/opencode/test-6251-cookies.txt -X POST -H "Content-Type: application/json" \
     -d '{"refs":[{"id":"test-6251-john.vcf","reference":"test-6251-john.vcf","email":"john.private@example.com","c_cn":"John Doe"}],"c_cn":"List 6251","nickname":"","description":""}' \
     "$base/SOGo/so/sogo-tests1/Contacts/personal/test-6251-list.vcf/saveAsList"
   curl -s -u $u "$base/SOGo/dav/sogo-tests1/Contacts/personal/test-6251-list.vcf" | grep CARD
   # expect: CARD;FN=John Doe;EMAIL=john.private@example.com:test-6251-john.vcf
   # re-save selecting board@example.com → stored EMAIL must become board@example.com
   # cleanup:
   curl -s -u $u -X DELETE "$base/SOGo/dav/sogo-tests1/Contacts/personal/test-6251-list.vcf"
   curl -s -u $u -X DELETE "$base/SOGo/dav/sogo-tests1/Contacts/personal/test-6251-john.vcf"
   ```

## Known related behavior (not changed, out of ticket scope)

`SoObjects/Contacts/SOGoContactGCSEntry.m:226` — saving a *contact* still resets the
stored member email of every list containing it to the contact's preferred address
(`[reference setEmail: [newCard preferredEMail]]`, together with `setFn:`). Keeping
the member's selection there as well (when still present on the card) would be a
sensible follow-up ticket.

## PR body draft

> ### fix(contacts): persist the selected email address of VLIST members (#6251)
>
> A VLIST member stores the chosen address as the `EMAIL` attribute of its `CARD`
> line, but the web editor never wrote the user's selection there: on save the
> server forced the member's address to the first entry of the contact's indexed
> `c_mail` list, members already present in the list were skipped entirely
> (`// TODO: update existing cards?`), and the Angular UI never sent the selected
> address (`$$email` is dropped by `$omit`). As a result, for any contact with
> several addresses the list silently fell back to an arbitrary "preferred"
> address after each save, and re-selecting another address could never persist —
> the exact behavior reported in #6251. The fix makes `UIxListEditor` honor the
> client-selected `email` of each member (falling back to the old first-of-`c_mail`
> behavior when absent), refresh the stored address of existing members on re-save,
> and makes `Card.$save` transmit the selected address; a new
> `NGVList -cardReferenceForReference:` accessor supports the update path.
>
> AVANT : liste « Invitations » → John Doe enregistré avec `EMAIL=board@…` (1ère
> adresse de `c_mail`) même après avoir sélectionné `john.private@…` et re-sauvegardé ;
> la réouverture affiche et utilise toujours l'adresse par défaut. APRÈS : la liste
> conserve exactement l'adresse choisie (`CARD;EMAIL=john.private@…`), elle peut être
> changée à chaque sauvegarde, et deux listes peuvent référencer le même contact via
> des adresses différentes (« Invitations » → privée, « Internal » → board). Couvert
> par `Tests/Unit/TestNGVList.m` (aller-retour VLIST/EMAIL) et
> `Tests/spec/HTTPListMembersSpec.js` (sauvegarde via l'API web : adresse choisie
> stockée, adresse non par défaut stockée, mise à jour d'un membre existant).
