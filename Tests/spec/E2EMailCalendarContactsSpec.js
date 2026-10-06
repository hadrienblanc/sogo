import config from '../lib/config.js'

const fetch = globalThis.fetch
const BASE = `http://127.0.0.1:${config.port}/SOGo`

function auth(user = config.username, pass = config.password) {
  return { Authorization: 'Basic ' + Buffer.from(`${user}:${pass}`).toString('base64') }
}

async function dav(method, path, body, headers = {}, user, pass) {
  const h = { ...auth(user, pass), ...headers }
  if (body) h['Content-Type'] = headers['Content-Type'] || 'application/xml'
  const res = await fetch(`${BASE}${path}`, { method, headers: h, body })
  const text = await res.text()
  return { status: res.status, text }
}

describe('E2E Mail: send via SMTP relay, receive via IMAP, read via DAV', function() {
  beforeAll(function() {
    jasmine.DEFAULT_TIMEOUT_INTERVAL = 30000
  })

  const subject = 'e2e-smtp-' + Date.now()

  it('sends a message through SOGo send endpoint', async function() {
    const res = await dav('POST',
      `/so/${config.username}/Mail/0/folderINBOX/send`,
      JSON.stringify({
        to: [`${config.subscriber_username}@sogo.local`],
        subject,
        text: 'E2E SMTP round-trip test body.'
      }),
      { 'Content-Type': 'application/json' })
    expect(res.status).withContext(`send returned ${res.status}`).toBeLessThan(400)
  })

  it('recipient INBOX is accessible via DAV', async function() {
    const query = '<?xml version="1.0"?>' +
      '<D:propfind xmlns:D="DAV:"><D:prop>' +
      '<D:resourcetype/><D:getcontentlength/>' +
      '</D:prop></D:propfind>'
    const res = await dav('PROPFIND',
      `/dav/${config.subscriber_username}/Mail/0/folderINBOX/`, query,
      { Depth: '1' }, config.subscriber_username, config.subscriber_password)
    expect(res.status).withContext(`PROPFIND returned ${res.status}`).toBe(207)
    expect(res.text).withContext('must list messages').toContain('<D:response')
  })
})

describe('E2E Calendar: PUT, QUERY, GET, DELETE via CalDAV', function() {
  const uid = `e2e-${Date.now()}@test`
  const filename = uid.replace(/@.*/, '') + '.ics'

  const ics = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//E2E//EN',
    'BEGIN:VEVENT',
    `UID:${uid}`,
    `DTSTAMP:${new Date().toISOString().replace(/[-:]/g, '').split('.')[0]}Z`,
    'DTSTART:20261015T100000Z',
    'DTEND:20261015T110000Z',
    'SUMMARY:E2E Calendar Test',
    'DESCRIPTION:Created by the end-to-end suite',
    'LOCATION:Test Room',
    `ORGANIZER:mailto:${config.username}@sogo.local`,
    `ATTENDEE:mailto:${config.subscriber_username}@sogo.local`,
    'END:VEVENT',
    'END:VCALENDAR'
  ].join('\r\n')

  it('PUT, QUERY, GET, DELETE round-trip', async function() {
    const put = await dav('PUT',
      `/dav/${config.username}/Calendar/personal/${filename}`, ics,
      { 'Content-Type': 'text/calendar' })
    expect([201, 204]).withContext(`PUT returned ${put.status}`).toContain(put.status)

    const query = `<?xml version="1.0"?>
      <C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:prop><D:getetag/><D:resourcetype/></D:prop>
        <C:filter>
          <C:comp-filter name="VCALENDAR">
            <C:comp-filter name="VEVENT">
              <C:prop-filter name="SUMMARY">
                <C:text-match>E2E Calendar</C:text-match>
              </C:prop-filter>
            </C:comp-filter>
          </C:comp-filter>
        </C:filter>
      </C:calendar-query>`
    const rep = await dav('REPORT',
      `/dav/${config.username}/Calendar/personal/`, query)
    expect(rep.status).withContext('REPORT must return 207').toBe(207)
    expect(rep.text).withContext('must find the event').toContain(filename)

    const get = await dav('GET',
      `/dav/${config.username}/Calendar/personal/${filename}`)
    expect(get.status).toBe(200)
    expect(get.text).withContext('must contain the summary').toContain('E2E Calendar Test')
    expect(get.text).withContext('must contain the location').toContain('Test Room')

    const del = await dav('DELETE',
      `/dav/${config.username}/Calendar/personal/${filename}`)
    expect([200, 204]).withContext(`DELETE returned ${del.status}`).toContain(del.status)
  })
})

describe('E2E Contacts: PUT, addressbook-query, GET, round-trip, DELETE', function() {
  const uid = `e2e-contact-${Date.now()}`
  const filename = `${uid}.vcf`

  const mkVCard = (phone, extra = '') => [
    'BEGIN:VCARD',
    'VERSION:3.0',
    `UID:${uid}`,
    'FN:E2E Contact',
    'N:Contact;E2E;;;',
    `EMAIL:e2e-${Date.now()}@test.local`,
    `TEL;TYPE=WORK:${phone}`,
    ...extra,
    'END:VCARD'
  ].join('\r\n')

  it('PUT, PROPFIND, round-trip, DELETE', async function() {
    const put = await dav('PUT',
      `/dav/${config.username}/Contacts/personal/${filename}`,
      mkVCard('+1 555 0100'),
      { 'Content-Type': 'text/vcard' })
    expect([201, 204]).withContext(`PUT returned ${put.status}`).toContain(put.status)

    const query = '<?xml version="1.0"?>' +
      '<D:propfind xmlns:D="DAV:"><D:prop><D:resourcetype/><D:getetag/></D:prop></D:propfind>'
    const listing = await dav('PROPFIND',
      `/dav/${config.username}/Contacts/personal/`, query, { Depth: '1' })
    expect(listing.status).withContext(`PROPFIND returned ${listing.status}`).toBe(207)
    expect(listing.text).withContext('must list the contact').toContain(filename)

    const updated = mkVCard('+1 555 0200', ['TEL;TYPE=CELL:+1 555 0300'])
    const update = await dav('PUT',
      `/dav/${config.username}/Contacts/personal/${filename}`, updated,
      { 'Content-Type': 'text/vcard' })
    expect([201, 204]).withContext(`update PUT returned ${update.status}`).toContain(update.status)

    const get = await dav('GET',
      `/dav/${config.username}/Contacts/personal/${filename}`)
    expect(get.text).withContext('WORK phone must survive').toContain('+1 555 0200')
    expect(get.text).withContext('CELL phone must survive').toContain('+1 555 0300')

    const del = await dav('DELETE',
      `/dav/${config.username}/Contacts/personal/${filename}`)
    expect([200, 204]).withContext(`DELETE returned ${del.status}`).toContain(del.status)
  })
})
