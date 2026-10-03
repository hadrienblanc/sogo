import config from '../lib/config.js'
import { default as WebDAV } from '../lib/WebDAV.js'
const fetch = globalThis.fetch

const message = `From: Cyril <cyril@cyril.dev>
To: sogo-tests1@example.com
Subject: test-6222 cyrillic labels
Message-ID: <test-6222-labels@cyril.dev>
Date: Thu, 01 Oct 2026 10:00:00 +0000
Content-Type: text/plain; charset=utf-8

Hello,

Can you read me?
`

describe('Mailer cyrillic labels (bug 6222)', function() {
  const mailbox = 'test-6222-labels'
  const folder = `folder${mailbox}`
  const cyrillicLabel = 'тест'

  let webdav
  let messageUid

  const _postAction = async function(action, data) {
    return await webdav.postHttp(`/SOGo/so/${config.username}/Mail/0/${folder}/${action}`,
                                 'application/json',
                                 JSON.stringify(data))
  }

  const _uidsInView = async function(options) {
    const response = await _postAction('view', options || {})
    expect(response.status)
      .withContext('HTTP status code when fetching the uids of the folder')
      .toBe(200)
    return await response.json()
  }

  const _tagsOnMessage = async function(uid) {
    const response = await _postAction('headers', {uids: [uid]})
    expect(response.status)
      .withContext('HTTP status code when fetching the headers of the message')
      .toBe(200)
    const headers = await response.json()
    return headers[1][9]
  }

  const _addCyrillicLabel = async function() {
    const response = await _postAction('addOrRemoveLabel',
                                       {operation: 'add', msgUIDs: [messageUid], flags: cyrillicLabel})
    expect(response.status)
      .withContext('HTTP status code when adding a cyrillic label')
      .toBe(204)
  }

  beforeAll(async function() {
    webdav = new WebDAV(config.username, config.password)

    const [response] = await webdav.makeCollection(`/SOGo/dav/${config.username}/Mail/0/${mailbox}`)
    expect(response.status)
      .withContext('HTTP status code when creating the test folder')
      .toBe(201)

    const put = await fetch(`${webdav.serverUrl}/SOGo/dav/${config.username}/Mail/0/${folder}/test-6222.eml`, {
      method: 'PUT',
      headers: { ...webdav.headers, 'Content-Type': 'message/rfc822' },
      body: message
    })
    expect(put.status)
      .withContext('HTTP status code when uploading the test message')
      .toBe(201)

    const data = await _uidsInView()
    messageUid = data.uids[0]
    expect(messageUid).withContext('uid of the uploaded message').toBeDefined()
  })

  afterAll(async function() {
    await webdav.deleteObject(`/SOGo/dav/${config.username}/Mail/0/${folder}`)
  })

  it('attaches a cyrillic tag to a message', async function() {
    await _addCyrillicLabel()
  })

  it('exposes the cyrillic label name on the folder', async function() {
    await _addCyrillicLabel()
    const response = await webdav.getHttp(`/SOGo/so/${config.username}/Mail/0/${folder}/labels`)
    expect(response.status)
      .withContext('HTTP status code when fetching the folder labels')
      .toBe(200)
    const labels = await response.json()
    expect(labels.filter(label => label.imapName == cyrillicLabel).length)
      .withContext('the cyrillic label is listed with its decoded name')
      .toBe(1)
  })

  it('shows the cyrillic tag on the message', async function() {
    await _addCyrillicLabel()
    const tags = await _tagsOnMessage(messageUid)
    expect(tags).withContext('tags of the message after adding a cyrillic label').toContain(cyrillicLabel)
  })

  it('filters the message list on the cyrillic label', async function() {
    await _addCyrillicLabel()
    const data = await _uidsInView({labels: [cyrillicLabel]})
    expect(data.uids)
      .withContext('uids matching the cyrillic label')
      .toEqual([messageUid])
  })

  it('removes the cyrillic tag from the message', async function() {
    const response = await _postAction('addOrRemoveLabel',
                                       {operation: 'remove', msgUIDs: [messageUid], flags: cyrillicLabel})
    expect(response.status)
      .withContext('HTTP status code when removing a cyrillic label')
      .toBe(204)
    const tags = await _tagsOnMessage(messageUid)
    expect(tags).withContext('tags of the message after removing the cyrillic label').not.toContain(cyrillicLabel)
  })
})
