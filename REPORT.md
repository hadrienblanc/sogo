# Ticket 6236 — Support structured calendar locations for iOS (EAS)

Branch: `fix-6236-mantis` — commit `feat(activesync): support EAS 16 structured
calendar locations on iOS (6236)`

## Root cause (file:line)

Two independent causes, both confirmed in the code (no runtime defect on the
server itself — this is a missing feature, not a regression):

1. **EAS 16.x is never negotiated.** SOGo advertises
   `MS-ASProtocolVersions: 2.5,12.0,12.1,14.0,14.1`
   (`ActiveSync/SoObjectWebDAVDispatcher+ActiveSync.m:66-67` for OPTIONS and
   `ActiveSync/SOGoActiveSyncDispatcher.m:4445-4447` for every POST response).
   iOS picks the highest mutually supported version, so it pins 14.1 and never
   sends/expects `AirSyncBase:Location` (an EAS 16.0 feature,
   [MS-ASWBXML](https://learn.microsoft.com/en-us/openspecs/exchange_server_protocols/ms-aswbxml/aa548cbc-b15f-4dc1-8bda-82b35d9d41c4)).
   Version-gated 16.x code paths already existed in the tree
   (`iCalEvent+ActiveSync.m:296,508`, `SOGoActiveSyncDispatcher+Sync.m:362`)
   but could never activate with iOS.

2. **Structured data is reduced to plain text even at ≥ 16.0.**
   - Outgoing (`ActiveSync/iCalEvent+ActiveSync.m:293-300`, before the fix):
     only `<Location><DisplayName>` was emitted from the iCal `LOCATION`
     string; `GEO` coordinates were ignored and no
     `X-APPLE-STRUCTURED-LOCATION` mapping existed anywhere in the tree
     (verified: zero matches for `GEO`/`Latitude`/`X-APPLE` in the parser,
     UI, or ActiveSync layers).
   - Incoming (`ActiveSync/iCalEvent+ActiveSync.m:587-590`, before the fix):
     of the whole `AirSyncBase:Location` dictionary sent by iOS only
     `DisplayName` was stored; Street/City/State/Country/PostalCode/
     Latitude/Longitude/LocationUri were dropped on the floor.
   - The same DisplayName-only emission existed for meeting requests embedded
     in emails (`ActiveSync/SOGoMailObject+ActiveSync.m:1073-1080`).

Read-only probe of the shared stack (http://127.0.0.1:50001): OPTIONS and WBXML
POSTs on `/SOGo/Microsoft-Server-ActiveSync` are not routed to the EAS dispatcher
by that build (plain 200/text responses, no `MS-ASProtocolVersions` header), so
the negotiation defect is evidenced from code; the deployed e2e image does build
libwbxml master, whose AirSyncBase table contains all 16.0 location elements
(Location 0x20, Street 0x22 … LocationUri 0x2c), so the WBXML layer supports it.

## What changed (before/after)

### 1. Protocol negotiation
- `ActiveSync/SoObjectWebDAVDispatcher+ActiveSync.m:66-67` and
  `ActiveSync/SOGoActiveSyncDispatcher.m:4445-4447`
- AVANT: `MS-Server-ActiveSync: 14.1`, `MS-ASProtocolVersions: 2.5,12.0,12.1,14.0,14.1`
- APRÈS: `MS-Server-ActiveSync: 16.1`, `MS-ASProtocolVersions: 2.5,12.0,12.1,14.0,14.1,16.0,16.1`
- iOS now negotiates 16.1, which activates the (already present and
  additionally completed) 16.x code paths. Per the reporter's question, this is
  deliberately decoupled from the rest of the EAS 16 feature set: the existing
  version gates in the tree are per-element and tolerate 16.x.

### 2. iCalendar ↔ AirSyncBase:Location mapping (`ActiveSync/iCalEvent+ActiveSync.m`)

New serializer `activeSyncStructuredLocationInContext:` (declared in
`iCalEvent+ActiveSync.h`), used for calendar items and email meeting requests:

- AVANT (event `LOCATION:Oslo S`, `GEO:59.911081;10.749770`,
  `X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-ADDRESS="Jernbanetorget 1\nOslo\n\n0154\nNorway";X-TITLE="Oslo S":geo:59.911081,10.749770`):
  ```xml
  <Location xmlns="AirSyncBase:"><DisplayName>Oslo S</DisplayName></Location>
  ```
- APRÈS (same event):
  ```xml
  <Location xmlns="AirSyncBase:">
    <DisplayName>Oslo S</DisplayName>
    <Street>Jernbanetorget 1</Street>
    <City>Oslo</City>
    <PostalCode>0154</PostalCode>
    <Country>Norway</Country>
    <Latitude>59.911081</Latitude>
    <Longitude>10.749770</Longitude>
    <LocationUri>geo:59.911081,10.749770</LocationUri>
  </Location>
  ```
  - `DisplayName` ← `LOCATION` (fallback: `X-TITLE`)
  - `Latitude`/`Longitude` ← `GEO` (`lat;lon` or `lat,lon`; the `geo:` URI of
    the structured property is used as fallback); unparseable `GEO` is ignored
  - `Street/City/State/Country/PostalCode` ← `X-ADDRESS` lines: 5 lines =
    Street, City, State, PostalCode, Country; 3 lines (Apple's common minimal
    form) = Street, City, Country; other shapes emit no components
  - `LocationUri` ← the URI value of `X-APPLE-STRUCTURED-LOCATION`
  - a `GEO`-only event yields a `Location` with coordinates only; empty
    components are simply omitted (missing data never blocks sync)
  - EAS < 16.0 output is unchanged: flat `<Location xmlns="Calendar:">`

New parser `_takeActiveSyncStructuredLocation:` called from
`takeActiveSyncValues:inContext:` when the negotiated version is ≥ 16.0:

- AVANT: `[self setLocation: [o objectForKey: @"DisplayName"]]` — everything
  else dropped.
- APRÈS: in addition to `LOCATION` = `DisplayName`, the structured payload is
  preserved durably in the calendar object:
  ```ical
  GEO:59.911081;10.749770
  X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-ADDRESS="Jernbanetorget 1\nOslo\n\n0154\nNorway";X-TITLE="Oslo S":geo:59.911081,10.749770
  ```
  i.e. coordinates in the RFC 5545 `GEO` property and the full structured
  location (address components in fixed slot order Street/City/State/
  PostalCode/Country, title, URI) in Apple's
  `X-APPLE-STRUCTURED-LOCATION` extension — readable by Apple Calendar over
  CalDAV as well. A `LocationUri` supplied by the client is kept verbatim;
  without one, a `geo:lat,lon` URI is synthesized from the coordinates. When a
  later client update carries only `DisplayName`, the stale `GEO` and
  structured property are removed.

### 3. Meeting requests (`ActiveSync/SOGoMailObject+ActiveSync.m:1073-1081`)
The email meeting-request serializer now reuses
`activeSyncStructuredLocationInContext:` at ≥ 16.0 instead of its own
DisplayName-only copy (legacy `Email:` flat form kept below 16.0).

### Scope notes
- `Accuracy`, `Altitude`, `AltitudeAccuracy` are accepted but not stored:
  iCalendar has no standard counterpart (Apple's `X-APPLE-RADIUS` is only a
  loose equivalent); they never prevent synchronization.
- The `< 16.0` wire behavior and `takeActiveSyncValues` flat-string handling
  are byte-for-byte unchanged (locked by tests).

## Tests

`Tests/Unit/TestiCalEvent+ActiveSync.m` (existing file, no GNUmakefile change
needed), 10 new tests:

- `test_structuredLocationIsExposedOnTheWire` — EAS-out mapping of all fields
- `test_locationStaysFlatBeforeProtocol16` — 14.1 keeps flat text, no
  AirSyncBase Location
- `test_structuredLocationRoundTrip` — iOS→SOGo→iOS round trip incl. address
  components, coordinates, LocationUri + the rendered Apple-compatible
  `X-APPLE-STRUCTURED-LOCATION` line (folded versit output unfolded)
- `test_displayNameOnlyLocationRoundTrip` — nothing invented, no GEO stored
- `test_plainLocationUpdateDropsStaleStructuredData` — stale GEO/structured
  property removed on plain-text update
- `test_locationUriWithoutCoordinatesRoundTrip` — missing coordinates do not
  prevent sync
- `test_geoOnlyEventExposesCoordinatesWithoutDisplayName`
- `test_appleThreeLineAddressMapsToStreetCityCountry` — Apple's 3-line
  X-ADDRESS + X-TITLE fallback for DisplayName
- `test_invalidGeoValueIsIgnored` — garbage GEO neither breaks sync nor emits
  coordinates
- `test_flatLocationAcceptedBeforeProtocol16` — legacy incoming flat string

Full suite: `local/run-worktree-tests.sh` → **280 tests, OK** (the two known
host-noise failures did not trigger on this run).
The two dispatcher files and the mail file cannot be compiled on the host (no
libwbxml); their edits were syntax-verified by diffing `gcc -fsyntax-only`
error output against the pristine HEAD versions (identical).

## Verification steps for the orchestrator

1. Unit suite (should be OK, 280 tests):
   ```
   /home/hadrienblanc/Projets/hadrienblanc/sogo/local/run-worktree-tests.sh \
     /home/hadrienblanc/Projets/hadrienblanc/sogo/wt/c36-6236
   ```
2. Negotiation, on a rebuilt e2e stack (the current shared stack build does
   not route EAS requests):
   ```
   curl -s -i -X OPTIONS -u sogo-tests1:sogo \
     "http://127.0.0.1:50001/Microsoft-Server-ActiveSync?Cmd=Options&DeviceId=probe&DeviceType=iPhone" \
     | grep -i "MS-ASProtocol"
   # expected: MS-ASProtocolVersions: 2.5,12.0,12.1,14.0,14.1,16.0,16.1
   #           MS-Server-ActiveSync: 16.1
   ```
   and on any POST response (e.g. FolderSync):
   ```
   printf '\x03\x01\x6a\x00\x00\x00\x07\x16\x12\x03\x30\x00\x01\x01\x01' |
   curl -s -i -X POST -u sogo-tests1:sogo -H "MS-ASProtocolVersion: 16.1" \
     -H "Content-Type: application/vnd.ms-sync.wbxml" --data-binary @- \
     "http://127.0.0.1:50001/SOGo/Microsoft-Server-ActiveSync?Cmd=FolderSync&DeviceId=probe&DeviceType=iPhone" \
     | grep -i "MS-ASProtocolVersions"
   ```
3. Real-device round trip (needs an actual iOS device): add an Exchange
   account, create an event at a recognized place (e.g. *Oslo S,
   Jernbanetorget 1, 0154 Oslo*), sync, then inspect the stored .ics via
   CalDAV (expect `GEO` + `X-APPLE-STRUCTURED-LOCATION` as shown above) and
   confirm iOS still shows the map pin after a second sync. No artifacts were
   left on the shared stack (probes were read-only and the EAS endpoint is
   unrouted there).

## PR body draft

Apple Calendar on iOS only exchanges structured locations (`AirSyncBase:
Location` with address components, coordinates and a location URI) over
Exchange ActiveSync 16.0+. SOGo advertised 14.1 at most, so iOS fell back to
the flat text `Calendar:Location` — no map suggestions, no coordinates, and
any structured data sent by 16.x-capable clients was truncated to its
`DisplayName` on storage.

This advertises EAS 16.0/16.1 in `MS-ASProtocolVersions` (OPTIONS and POST
responses), which activates — and completes — the existing 16.x code paths
independently of the rest of the EAS 16 feature set. Calendar events (and
meeting requests embedded in emails) now serialize
`LOCATION`/`GEO`/`X-APPLE-STRUCTURED-LOCATION` into the full
`AirSyncBase:Location` element (`DisplayName`, `Street`, `City`, `State`,
`Country`, `PostalCode`, `Latitude`, `Longitude`, `LocationUri`), and every
structured field received from a 16.x client is preserved durably as RFC 5545
`GEO` plus an Apple-compatible `X-APPLE-STRUCTURED-LOCATION` property, so the
data survives iOS → SOGo → iOS round trips without ever being reduced to plain
text. Missing coordinates or address components never prevent synchronization;
clients negotiating < 16.0 keep the exact previous flat behavior, and a
plain-text location update correctly clears stale structured data. AVANT:
`<Location xmlns="AirSyncBase:"><DisplayName>Oslo S</DisplayName></Location>`.
APRÈS: `<Location xmlns="AirSyncBase:"><DisplayName>Oslo S</DisplayName>
<Street>Jernbanetorget 1</Street><City>Oslo</City><PostalCode>0154</PostalCode>
<Country>Norway</Country><Latitude>59.911081</Latitude>
<Longitude>10.749770</Longitude><LocationUri>geo:59.911081,10.749770</LocationUri>
</Location>` — ten new unit tests lock both directions.
