import config from '../lib/config'
import WebDAV from '../lib/WebDAV'

let webdav

const cardName = 'test-6251-john.vcf'
const listName = 'test-6251-list.vcf'
const davAddressBook = `/SOGo/dav/${config.username}/Contacts/personal`
const soAddressBook = `/SOGo/so/${config.username}/Contacts/personal`

const vcard = [
  'BEGIN:VCARD',
  'VERSION:3.0',
  `UID:test-6251-john`,
  'N:Doe;John',
  'FN:John Doe 6251',
  'EMAIL;TYPE=home:john.private@example.com',
  'EMAIL;TYPE=work:board@example.com',
  'END:VCARD'
].join('\r\n')

const vlist = [
  'BEGIN:VLIST',
  `UID:${listName}`,
  'VERSION:1.0',
  'FN:List 6251',
  'END:VLIST'
].join('\r\n')

const saveList = async function(selectedEmail) {
  const payload = JSON.stringify({
    c_cn: 'List 6251',
    nickname: '',
    description: '',
    refs: [
      {
        id: cardName,
        reference: cardName,
        email: selectedEmail,
        c_cn: 'John Doe 6251'
      }
    ]
  })

  const response = await webdav.postHttp(`${soAddressBook}/${encodeURIComponent(listName)}/saveAsList`,
                                         'application/json', payload)
  expect(response.status)
    .withContext(`HTTP status code when saving the list with ${selectedEmail} selected`)
    .toBe(200)
}

const storedMemberEmail = async function() {
  const [response] = await webdav.getCard(`${davAddressBook}/`, listName)
  const body = await response.text()
  const card = body.split('\r\n').find(line => line.startsWith('CARD;'))

  expect(card)
    .withContext('the VLIST must hold a CARD member line')
    .toBeDefined()

  const email = card.match(/EMAIL=([^;:]+)/)

  return email ? email[1] : undefined
}

const cleanup = async function() {
  await webdav.deleteObject(`${davAddressBook}/${listName}`)
  await webdav.deleteObject(`${davAddressBook}/${cardName}`)
}

beforeAll(function () {
  jasmine.DEFAULT_TIMEOUT_INTERVAL = config.timeout || 10000;
});

describe('HTTP Contacts list members', function() {

  beforeAll(async function() {
    webdav = new WebDAV(config.username, config.password)
  })

  beforeEach(async function() {
    await cleanup()
    const contact = await webdav.createVCard(`${davAddressBook}/`, cardName, vcard)
    expect(contact.status).toBe(201)
    const list = await webdav.createVCard(`${davAddressBook}/`, listName, vlist)
    expect(list.status).toBe(201)
  })

  afterEach(async function() {
    await cleanup()
  })

  it('keeps the email address selected for a contact with multiple addresses', async function() {
    await saveList('board@example.com')

    expect(await storedMemberEmail())
      .withContext('the selected work address must be stored on the member')
      .toBe('board@example.com')
  })

  it('keeps a non-default email address selected for a member', async function() {
    await saveList('john.private@example.com')

    expect(await storedMemberEmail())
      .withContext('the selected private address must be stored on the member')
      .toBe('john.private@example.com')
  })

  it('updates the stored email address of an existing member', async function() {
    await saveList('board@example.com')
    await saveList('john.private@example.com')

    expect(await storedMemberEmail())
      .withContext('re-saving the list with another selected address must update the member')
      .toBe('john.private@example.com')
  })

})
