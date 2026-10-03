import config from '../lib/config.js'
import { default as WebDAV } from '../lib/WebDAV.js'
import Preferences from '../lib/Preferences.js'

const fetch = globalThis.fetch

//
// System test of the threaded "changes" refresh (bugs.sogo.nu #6231): when
// the thread view is enabled and a mailbox changed since the sync token, the
// incremental refresh must return the full folder state (threaded uids +
// headers) instead of a flat list of changed uids, so that newly received
// replies are folded into their conversation by the web client.

const mailbox = 'test-6231-threaded-changes'
const resource = `/SOGo/dav/${config.username}/Mail/0/`

const rootMessage = `Message-ID: <test-6231-root@example.com>
Date: Sat, 03 Oct 2026 10:00:00 +0200
From: External Sender <sender@example.com>
To: SOGo Tests <${config.username}@example.com>
Subject: test-6231 threaded changes
Content-Type: text/plain; charset=utf-8

Original message.
`

const replyMessage = `Message-ID: <test-6231-reply@example.com>
Date: Sat, 03 Oct 2026 11:00:00 +0200
From: External Sender <sender@example.com>
To: SOGo Tests <${config.username}@example.com>
In-Reply-To: <test-6231-root@example.com>
References: <test-6231-root@example.com>
Subject: Re: test-6231 threaded changes
Content-Type: text/plain; charset=utf-8

First reply.
`

const _putMessage = async function (webdav, message) {
  const response = await fetch(webdav.serverUrl + resource + `folder${mailbox}`, {
    method: 'PUT',
    headers: { ...webdav.headers, 'Content-Type': 'message/rfc822' },
    body: message
  })
  expect(response.status)
    .withContext('HTTP status code when putting a message')
    .toBe(201)
}

const _viewFolder = async function (preferences) {
  const response = await fetch(preferences.serverUrl
                                + `/SOGo/so/${config.username}/Mail/0/folder${mailbox}/view`, {
    method: 'GET',
    headers: { Cookie: await preferences.getAuthCookie() }
  })
  expect(response.status)
    .withContext('HTTP status code when fetching the folder view')
    .toBe(200)
  return await response.json()
}

const _fetchChanges = async function (preferences, syncToken) {
  const response = await fetch(preferences.serverUrl
                                + `/SOGo/so/${config.username}/Mail/0/folder${mailbox}/changes`, {
    method: 'POST',
    headers: {
      Cookie: await preferences.getAuthCookie(),
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      syncToken: syncToken,
      sortingAttributes: { sort: 'date', asc: false, match: 'OR' }
    })
  })
  expect(response.status)
    .withContext('HTTP status code when fetching folder changes')
    .toBe(200)
  return await response.json()
}

describe('Threaded refresh of the message list (bug 6231)', function() {

  let webdav
  let preferences
  let originalPreference
  let syncToken

  beforeAll(async function() {
    webdav = new WebDAV(config.username, config.password)
    preferences = new Preferences(config.username, config.password)

    originalPreference = await preferences.get('SOGoMailSortByThreads')

    const [response] = await webdav.makeCollection(resource + mailbox)
    expect(response.status)
      .withContext('HTTP status code when creating the mailbox')
      .toBe(201)

    await _putMessage(webdav, rootMessage)

    await preferences.set('SOGoMailSortByThreads', 1)

    const view = await _viewFolder(preferences)
    expect(view.threaded)
      .withContext('the thread view must be enabled for the user')
      .toBeTrue()
    syncToken = view.syncToken
    expect(syncToken)
      .withContext('the initial view must return a sync token')
      .toBeDefined()
  })

  afterAll(async function() {
    if (originalPreference !== null)
      await preferences.set('SOGoMailSortByThreads', originalPreference)
    else
      await preferences.set('SOGoMailSortByThreads', 0)
    await webdav.deleteObject(resource + mailbox)
  })

  it('returns the full folder state when a reply arrived (bug 6231)', async function() {
    await _putMessage(webdav, replyMessage)

    const changes = await _fetchChanges(preferences, syncToken)

    expect(changes.uids)
      .withContext('a threaded changes response must carry the full uids list')
      .toBeDefined()
    expect(changes.threaded)
      .withContext('the resync payload must announce threading')
      .toBeTrue()
    expect(changes.headers)
      .withContext('the resync payload must carry the message headers')
      .toBeDefined()
    expect(changes.changed)
      .withContext('a threaded changes response must not carry flat changed uids')
      .toBeUndefined()
    expect(changes.deleted)
      .withContext('a threaded changes response must not carry flat deleted uids')
      .toBeUndefined()
  })

  it('groups the newly received reply into the existing conversation', async function() {
    const view = await _viewFolder(preferences)

    expect(view.uids[0])
      .withContext('the thread metadata header must be the first uids entry')
      .toEqual(['uid', 'level', 'first'])

    const entries = view.uids.slice(1)
    expect(entries.length)
      .withContext('both messages of the conversation must be listed')
      .toBe(2)

    const first = entries.find(entry => entry[2] === 1)
    const member = entries.find(entry => entry[2] !== 1)
    expect(first)
      .withContext('the conversation must have a thread head')
      .toBeDefined()
    expect(member)
      .withContext('the reply must be a thread member, not a standalone message')
      .toBeDefined()
    expect(member[1])
      .withContext('the reply must be nested under the thread head')
      .toBeGreaterThanOrEqual(0)
  })

  it('returns the sync token alone when nothing changed', async function() {
    const view = await _viewFolder(preferences)
    const changes = await _fetchChanges(preferences, view.syncToken)

    expect(changes.uids)
      .withContext('an unchanged folder must not trigger a resync')
      .toBeUndefined()
    expect(changes.syncToken)
      .withContext('the current sync token must be returned')
      .toBe(view.syncToken)
  })
})
