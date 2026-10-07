import config from '../lib/config.js'

const fetch = globalThis.fetch
const BASE = `http://${config.hostname}:${config.port}/SOGo`

function basicAuth(user, pass) {
  return { Authorization: 'Basic ' + Buffer.from(`${user}:${pass}`).toString('base64') }
}

let session = null

async function login() {
  const res = await fetch(`${BASE}/connect`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userName: config.username, password: config.password })
  })
  expect(res.status).withContext('login via /connect').toBe(200)
  const cookies = []
  for (const value of res.headers.getSetCookie()) {
    const [pair] = value.split(';')
    cookies.push(pair)
  }
  return cookies.join('; ')
}

async function api(method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { Cookie: session },
    body: body ? JSON.stringify(body) : undefined
  })
  return { status: res.status, data: await res.json().catch(() => null) }
}

const soFolder = name => `/so/${config.username}/Mail/0/folderINBOX/folder${name}`
const davFolder = name => `${BASE}/dav/${config.username}/Mail/0/folderINBOX/folder${name}`

async function createFolder(name) {
  const res = await api('POST', `/so/${config.username}/Mail/0/folderINBOX/createFolder`, { name })
  expect(res.status).withContext(`createFolder returned ${res.status}`).toBe(204)
}

async function deleteFolder(name) {
  const res = await api('POST', `${soFolder(name)}/delete`, { withoutTrash: true })
  expect(res.status).withContext(`delete of ${name} returned ${res.status}`).toBe(204)
}

async function putMessage(name, subject) {
  const message = [
    `Message-ID: <${subject}@c294.spec>`,
    `Date: ${new Date().toUTCString()}`,
    `From: E2E Spec <spec@sogo.local>`,
    `To: ${config.username}@sogo.local`,
    `Subject: ${subject}`,
    'Content-Type: text/plain; charset=utf-8',
    '',
    'Folder actions test body.'
  ].join('\r\n') + '\r\n'
  const res = await fetch(davFolder(name), {
    method: 'PUT',
    headers: { ...basicAuth(config.username, config.password), 'Content-Type': 'message/rfc822' },
    body: message
  })
  expect(res.status).withContext(`DAV PUT of message into ${name} returned ${res.status}`).toBe(201)
}

async function folderView(path) {
  const res = await api('POST', `${path}/view`, {})
  expect(res.status).withContext(`view of ${path} returned ${res.status}`).toBe(200)
  return res.data
}

function messagesOf(view) {
  if (!view.headers || !view.headers[0])
    return []
  const [columns, ...rows] = view.headers
  return rows.map(row => ({
    uid: row[columns.indexOf('uid')],
    subject: row[columns.indexOf('Subject')],
    isFlagged: row[columns.indexOf('isFlagged')]
  }))
}

function uidOfSubject(view, subject) {
  const match = messagesOf(view).filter(m => m.subject === subject)
  expect(match.length).withContext(`message "${subject}" must be in the folder`).toBeGreaterThan(0)
  return match[0].uid
}

async function propfindStatus(path) {
  const res = await fetch(`${BASE}${path}`, {
    method: 'PROPFIND',
    headers: { ...basicAuth(config.username, config.password), Depth: '0' },
    body: '<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop><D:resourcetype/></D:prop></D:propfind>'
  })
  return res.status
}

async function emptyTrash() {
  const res = await api('POST', `/so/${config.username}/Mail/0/folderTrash/emptyTrash`, {})
  expect(res.status).withContext(`emptyTrash returned ${res.status}`).toBe(200)
}

describe('Mailer folder-level server actions (so JSON API)', function() {
  beforeAll(async function() {
    jasmine.DEFAULT_TIMEOUT_INTERVAL = 30000
    session = await login()
  })

  it('renames a folder and its messages follow', async function() {
    const name = `test-c294-ren-${Date.now()}`
    const renamed = `${name}-after`
    const subject = `c294-ren-${name}`
    try {
      await createFolder(name)
      await putMessage(name, subject)

      const res = await api('POST', `${soFolder(name)}/save`, { name: renamed })
      expect(res.status).withContext(`rename returned ${res.status}`).toBe(200)
      expect(res.data.path).withContext('response must expose the new path').toBe(`INBOX/${renamed}`)
      expect(res.data.sievePath).withContext('response must expose the sieve path').toBe(`INBOX/${renamed}`)

      expect(await propfindStatus(`/dav/${config.username}/Mail/0/folderINBOX/folder${renamed}`))
        .withContext('renamed folder must exist').toBe(207)
      const stale = await api('POST', `${soFolder(name)}/view`, {})
      expect(stale.status).withContext('listing the old name must fail').toBe(500)

      const view = await folderView(soFolder(renamed))
      expect(messagesOf(view).map(m => m.subject))
        .withContext('message must survive the rename').toEqual([subject])
    }
    finally {
      await deleteFolder(renamed).catch(() => {})
    }
  })

  it('forwards a message as an attachment into a new draft', async function() {
    const name = `test-c294-fwd-${Date.now()}`
    const subject = `c294-fwd-${name}`
    try {
      await createFolder(name)
      await putMessage(name, subject)
      const uid = uidOfSubject(await folderView(soFolder(name)), subject)

      const res = await api('POST', `${soFolder(name)}/forwardMessages`, { uids: [uid] })
      expect(res.status).withContext(`forwardMessages returned ${res.status}`).toBe(201)
      expect(res.data.mailboxPath).withContext('draft must land in Drafts').toBe('Drafts')
      const draftUid = res.data.uid
      expect(draftUid).withContext('response must return the draft uid').toBeDefined()

      const drafts = await folderView(`/so/${config.username}/Mail/0/folderDrafts`)
      expect(drafts.uids).withContext('draft must be listed in Drafts').toContain(draftUid)

      const draft = await fetch(`${BASE}/dav/${config.username}/Mail/0/folderDrafts/${draftUid}.eml`,
        { headers: basicAuth(config.username, config.password) })
      expect(draft.status).toBe(200)
      const eml = await draft.text()
      expect(eml).withContext('original message must be attached as rfc822').toContain('message/rfc822')
      expect(eml).withContext('attachment must carry the original subject').toContain(subject)

      const purge = await api('POST', `/so/${config.username}/Mail/0/folderDrafts/batchDelete`, { uids: [draftUid] })
      expect(purge.status).withContext('draft cleanup returned ' + purge.status).toBe(200)
      await emptyTrash()
    }
    finally {
      await deleteFolder(name).catch(() => {})
    }
  })

  it('empties the trash folder', async function() {
    const name = `test-c294-trash-${Date.now()}`
    const subject = `c294-trash-${name}`
    try {
      await createFolder(name)
      await putMessage(name, subject)
      const uid = uidOfSubject(await folderView(soFolder(name)), subject)

      const del = await api('POST', `${soFolder(name)}/batchDelete`, { uids: [uid] })
      expect(del.status).withContext(`batchDelete returned ${del.status}`).toBe(200)
      const trash = await folderView(`/so/${config.username}/Mail/0/folderTrash`)
      expect(messagesOf(trash).map(m => m.subject))
        .withContext('message must land in Trash first').toContain(subject)

      await emptyTrash()

      const after = await folderView(`/so/${config.username}/Mail/0/folderTrash`)
      expect(after.uids).withContext('Trash must be empty after emptyTrash').toEqual([])
    }
    finally {
      await deleteFolder(name).catch(() => {})
    }
  })

  it('toggles the flagged state of a single message', async function() {
    const name = `test-c294-flag-${Date.now()}`
    const subject = `c294-flag-${name}`
    try {
      await createFolder(name)
      await putMessage(name, subject)
      const uid = uidOfSubject(await folderView(soFolder(name)), subject)

      const flag = await api('POST', `${soFolder(name)}/${uid}/markMessageFlagged`, {})
      expect(flag.status).withContext(`markMessageFlagged returned ${flag.status}`).toBe(204)
      expect(messagesOf(await folderView(soFolder(name)))[0].isFlagged)
        .withContext('message must appear flagged in the listing').toBeTrue()

      const unflag = await api('POST', `${soFolder(name)}/${uid}/markMessageUnflagged`, {})
      expect(unflag.status).withContext(`markMessageUnflagged returned ${unflag.status}`).toBe(204)
      expect(messagesOf(await folderView(soFolder(name)))[0].isFlagged)
        .withContext('message must appear unflagged in the listing').toBeFalse()
    }
    finally {
      await deleteFolder(name).catch(() => {})
    }
  })
})
