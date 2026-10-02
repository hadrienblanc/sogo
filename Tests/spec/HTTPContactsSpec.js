import config from '../lib/config'
import WebDAV from '../lib/WebDAV'

let webdav

const cardUid = 'test-6242-uid-at@horde.tachtler.net'
const cardName = `${cardUid}.vcf`
const davAddressBook = `/SOGo/dav/${config.username}/Contacts/personal`
const soAddressBook = `/SOGo/so/${config.username}/Contacts/personal`

const vcard = [
  'BEGIN:VCARD',
  'VERSION:3.0',
  `UID:${cardUid}`,
  'N:Doe;John',
  'FN:John Doe 6242',
  'EMAIL:johndoe6242@example.com',
  'END:VCARD'
].join('\r\n')

const savePayload = JSON.stringify({
  c_component: 'vcard',
  c_givenname: 'John',
  c_sn: 'Doe',
  c_cn: 'John Doe 6242',
  emails: [ { type: 'work', value: 'johndoe6242@example.com' } ],
  ignoreDuplicate: true
})

const countCards = async function() {
  const response = await webdav.propfindWebdavRaw(`${davAddressBook}/`, [ 'resourcetype' ], { depth: new String(1) })
  const body = await response.text()

  return (body.match(/test-6242-uid-at[^<]*\.vcf/g) || []).length
}

const cleanupCard = async function() {
  await webdav.deleteObject(`${davAddressBook}/${cardName}`)
  await webdav.deleteObject(`${davAddressBook}/${encodeURIComponent(encodeURIComponent(cardName))}`)
}

beforeAll(function () {
  jasmine.DEFAULT_TIMEOUT_INTERVAL = config.timeout || 10000;
});

describe('HTTP Contacts', function() {

  beforeAll(async function() {
    webdav = new WebDAV(config.username, config.password)
  })

  afterEach(async function() {
    await cleanupCard()
  })

  it('Save a card whose UID holds an @ from an URL-escaped card id', async function() {
    const creation = await webdav.createVCard(davAddressBook + '/', cardName, vcard)
    expect(creation.status)
      .withContext(`HTTP status code when creating the card over CardDAV`)
      .toBe(201)

    const response = await webdav.postHttp(`${soAddressBook}/${encodeURIComponent(cardName)}/saveAsContact`,
                                           'application/json', savePayload)
    expect(response.status)
      .withContext(`HTTP status code when saving the card from the web UI`)
      .toBe(200)

    const body = await response.json()
    expect(body.id)
      .withContext(`card id returned by the web UI save must be the decoded name`)
      .toBe(cardName)

    const cards = await countCards()
    expect(cards)
      .withContext(`no duplicate card must be created by the web UI save`)
      .toBe(1)
  })

  it('Save a card whose UID holds an @ from an over-escaped card id', async function() {
    const creation = await webdav.createVCard(davAddressBook + '/', cardName, vcard)
    expect(creation.status)
      .withContext(`HTTP status code when creating the card over CardDAV`)
      .toBe(201)

    const response = await webdav.postHttp(`${soAddressBook}/${encodeURIComponent(encodeURIComponent(cardName))}/saveAsContact`,
                                           'application/json', savePayload)
    expect(response.status)
      .withContext(`HTTP status code when saving the card from the web UI`)
      .toBe(200)

    const body = await response.json()
    expect(body.id)
      .withContext(`card id returned by the web UI save must be the decoded name`)
      .toBe(cardName)

    const cards = await countCards()
    expect(cards)
      .withContext(`no duplicate card must be created by the web UI save`)
      .toBe(1)
  })

})
