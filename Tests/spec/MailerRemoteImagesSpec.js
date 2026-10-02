import config from '../lib/config.js'
import Preferences from '../lib/Preferences.js'
import { default as WebDAV } from '../lib/WebDAV.js'
const fetch = globalThis.fetch

//
// Server side of bugs.sogo.nu #6170: when the user preference
// SOGoMailDisplayRemoteInlineImages is set to "known", the message view
// must report whether the sender is listed in the address book
// (senderInAddressBook) so the web client can unblock remote inline
// images for known senders only.

const htmlBody = (color) =>
`<html><body><p>test-6170 remote image ${color}</p>` +
`<img src="http://tracker.example/${color}.png"/></body></html>`

const knownSenderMessage = `Message-ID: <test-6170-known@sogo.local>
From: "Known Sender" <test-6170-known@sogo.local>
To: ${config.username}@sogo.local
Subject: test-6170 remote images from known sender
Date: Fri, 02 Oct 2026 10:00:00 +0200
MIME-Version: 1.0
Content-Type: text/html; charset="us-ascii"
Content-Transfer-Encoding: 7bit

${htmlBody('known')}
`

const substringSpoofMessage = `Message-ID: <test-6170-spoof@sogo.local>
From: "Spoofer" <6170-known@sogo.local>
To: ${config.username}@sogo.local
Subject: test-6170 remote images from substring spoofer
Date: Fri, 02 Oct 2026 10:01:00 +0200
MIME-Version: 1.0
Content-Type: text/html; charset="us-ascii"
Content-Transfer-Encoding: 7bit

${htmlBody('spoof')}
`

const missingFromMessage = `Message-ID: <test-6170-nofrom@sogo.local>
To: ${config.username}@sogo.local
Subject: test-6170 remote images without From header
Date: Fri, 02 Oct 2026 10:02:00 +0200
MIME-Version: 1.0
Content-Type: text/html; charset="us-ascii"
Content-Transfer-Encoding: 7bit

${htmlBody('nofrom')}
`

const cardUid = 'test-6170-known-card'
const cardName = `${cardUid}.vcf`

const vcard = [
  'BEGIN:VCARD',
  'VERSION:3.0',
  `UID:${cardUid}`,
  'N:Sender;Known',
  'FN:Known Sender',
  'EMAIL;TYPE=work:test-6170-known@sogo.local',
  'END:VCARD'
].join('\r\n')

describe('Mail remote inline images from known senders (bug 6170)', function() {

  const mailbox = 'test-6170-remote-images'
  const resource = `/SOGo/dav/${config.username}/Mail/0/`
  const davAddressBook = `/SOGo/dav/${config.username}/Contacts/personal`

  let webdav
  let preferences
  let originalPreference
  let knownSenderLocation
  let substringSpoofLocation
  let missingFromLocation

  const _putMessage = async function (path, message) {
    const response = await fetch(webdav.serverUrl + resource + `folder${path}`, {
      method: 'PUT',
      headers: { ...webdav.headers, 'Content-Type': 'message/rfc822' },
      body: message
    })
    expect(response.status)
      .withContext('HTTP status code when putting a message')
      .toBe(201)
    return response.headers.get('location')
  }

  const _fetchView = async function (location) {
    const uid = location.split('/').pop().replace(/\.eml$/, '')
    const viewURL = `/SOGo/so/${config.username}/Mail/0/folder${mailbox}/${uid}/view`
    const response = await fetch(preferences.serverUrl + viewURL, {
      method: 'GET',
      headers: { Cookie: await preferences.getAuthCookie() }
    })
    expect(response.status)
      .withContext('HTTP status code when fetching the message view')
      .toBe(200)
    return await response.json()
  }

  beforeAll(async function() {
    webdav = new WebDAV(config.username, config.password)
    preferences = new Preferences(config.username, config.password)

    originalPreference = await preferences.get('SOGoMailDisplayRemoteInlineImages')

    const [response] = await webdav.makeCollection(resource + mailbox)
    expect(response.status)
      .withContext('HTTP status code when creating the mailbox')
      .toBe(201)

    const creation = await webdav.createVCard(davAddressBook + '/', cardName, vcard)
    expect(creation.status)
      .withContext('HTTP status code when creating the card of the known sender')
      .toBe(201)

    knownSenderLocation = await _putMessage(mailbox, knownSenderMessage)
    substringSpoofLocation = await _putMessage(mailbox, substringSpoofMessage)
    missingFromLocation = await _putMessage(mailbox, missingFromMessage)

    await preferences.set('SOGoMailDisplayRemoteInlineImages', 'known')
  })

  afterAll(async function() {
    if (originalPreference !== null)
      await preferences.set('SOGoMailDisplayRemoteInlineImages', originalPreference)
    await webdav.deleteObject(`${davAddressBook}/${cardName}`)
    await webdav.deleteObject(resource + `folder${mailbox}`)
  })

  it('reports a sender listed in the address book as known', async function() {
    const data = await _fetchView(knownSenderLocation)

    expect(data.senderInAddressBook)
      .withContext('a sender with an exact matching card must be flagged known')
      .toBe(true)
    expect(data.parts.content)
      .withContext('the message body must still be sanitized server-side')
      .toContain('unsafe-src="http://tracker.example/known.png"')
  })

  it('does not flag a sender whose address is only a substring of a card email', async function() {
    const data = await _fetchView(substringSpoofLocation)

    expect(data.senderInAddressBook)
      .withContext('a substring match on a card email must not count as a known sender')
      .toBe(false)
  })

  it('does not flag a message without a From header', async function() {
    const data = await _fetchView(missingFromLocation)

    expect(data.senderInAddressBook)
      .withContext('a message without From must not be flagged known')
      .toBe(false)
  })

  it('omits the known-sender flag when the preference is not "known"', async function() {
    await preferences.set('SOGoMailDisplayRemoteInlineImages',
                          originalPreference || 'never')
    const data = await _fetchView(knownSenderLocation)

    expect(data.senderInAddressBook)
      .withContext('the flag must only be computed for the "known" preference')
      .toBeUndefined()
  })

})
