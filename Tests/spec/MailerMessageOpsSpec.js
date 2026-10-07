import config from '../lib/config.js'

const fetch = globalThis.fetch
const BASE = `http://${config.hostname}:${config.port}/SOGo`

function basicAuth(user, pass) {
  return { Authorization: 'Basic ' + Buffer.from(`${user}:${pass}`).toString('base64') }
}

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

let session = null

async function api(method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { Cookie: session },
    body: body ? JSON.stringify(body) : undefined
  })
  return { status: res.status, data: await res.json().catch(() => null) }
}

async function apiRaw(method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { Cookie: session },
    body: body ? JSON.stringify(body) : undefined
  })
  return {
    status: res.status,
    contentType: res.headers.get('content-type') || '',
    disposition: res.headers.get('content-disposition') || '',
    buffer: Buffer.from(await res.arrayBuffer())
  }
}

const soFolder = name => `/so/${config.username}/Mail/0/folderINBOX/folder${name}`
const davFolder = name => `${BASE}/dav/${config.username}/Mail/0/folderINBOX/folder${name}`

async function createFolder(name) {
  const res = await api('POST', `/so/${config.username}/Mail/0/folderINBOX/createFolder`, { name })
  expect(res.status).withContext(`createFolder returned ${res.status} (${JSON.stringify(res.data)})`).toBe(204)
}

async function deleteFolder(name) {
  const res = await api('POST', `${soFolder(name)}/delete`, { withoutTrash: true })
  expect(res.status).withContext(`delete of ${name} returned ${res.status}`).toBe(204)
}

async function putMessage(name, subject) {
  const message = [
    `Message-ID: <${subject}@c293.spec>`,
    `Date: ${new Date().toUTCString()}`,
    `From: E2E Spec <spec@sogo.local>`,
    `To: ${config.username}@sogo.local`,
    `Subject: ${subject}`,
    'Content-Type: text/plain; charset=utf-8',
    '',
    'Message operations test body.'
  ].join('\r\n') + '\r\n'
  const res = await fetch(davFolder(name), {
    method: 'PUT',
    headers: { ...basicAuth(config.username, config.password), 'Content-Type': 'message/rfc822' },
    body: message
  })
  expect(res.status).withContext(`DAV PUT of message into ${name} returned ${res.status}`).toBe(201)
}

async function folderView(name) {
  const res = await api('GET', `${soFolder(name)}/view`)
  expect(res.status).withContext(`view of ${name} returned ${res.status}`).toBe(200)
  return res.data
}

function messagesOf(view) {
  if (!view.headers || !view.headers[0])
    return []
  const [columns, ...rows] = view.headers
  const subjectIndex = columns.indexOf('Subject')
  const uidIndex = columns.indexOf('uid')
  return rows.map(row => ({ uid: row[uidIndex], subject: row[subjectIndex] }))
}

function subjectsOf(view) {
  return messagesOf(view).map(m => m.subject)
}

function uidOfSubject(view, subject) {
  const match = messagesOf(view).filter(m => m.subject === subject)
  expect(match.length).withContext(`message "${subject}" must be in the folder`).toBeGreaterThan(0)
  return match[0].uid
}

async function trashView() {
  const res = await api('GET', `/so/${config.username}/Mail/0/folderTrash/view`)
  expect(res.status).withContext(`view of Trash returned ${res.status}`).toBe(200)
  return res.data
}

describe('Mailer message operations (so JSON API)', function() {
  beforeAll(async function() {
    jasmine.DEFAULT_TIMEOUT_INTERVAL = 30000
    session = await login()
  })

  it('marks a whole folder as read', async function() {
    const name = `test-c293-read-${Date.now()}`
    try {
      await createFolder(name)
      await putMessage(name, `c293-read-a-${name}`)
      await putMessage(name, `c293-read-b-${name}`)

      const before = await folderView(name)
      expect(before.unseenCount).withContext('freshly delivered messages must be unread').toBe(2)

      const res = await api('POST', `${soFolder(name)}/markRead`, {})
      expect(res.status).withContext(`markFolderRead returned ${res.status}`).toBe(204)

      const after = await folderView(name)
      expect(after.unseenCount).withContext('folder must be fully read after markFolderRead').toBe(0)
      expect(subjectsOf(after).length).withContext('messages must still be there, only flagged as seen').toBe(2)
    }
    finally {
      await deleteFolder(name).catch(() => {})
    }
  })

  it('moves a message to Trash on delete, then deletes it permanently', async function() {
    const name = `test-c293-del-${Date.now()}`
    const subject = `c293-del-${name}`
    try {
      await createFolder(name)
      await putMessage(name, subject)
      const uid = uidOfSubject(await folderView(name), subject)

      const res = await api('POST', `${soFolder(name)}/batchDelete`, { uids: [uid] })
      expect(res.status).withContext(`batchDelete returned ${res.status}`).toBe(200)

      expect(subjectsOf(await folderView(name))).withContext('message must leave its folder').toEqual([])

      const trashBefore = await trashView()
      const trashUid = uidOfSubject(trashBefore, subject)
      expect(trashUid).withContext('message must have landed in Trash').toBeDefined()

      const purge = await api('POST', `/so/${config.username}/Mail/0/folderTrash/batchDelete`,
        { uids: [trashUid], withoutTrash: true })
      expect(purge.status).withContext(`permanent delete returned ${purge.status}`).toBe(200)

      expect(subjectsOf(await trashView())).withContext('message must be gone from Trash').not.toContain(subject)
    }
    finally {
      await deleteFolder(name).catch(() => {})
    }
  })

  it('archives selected messages as a zip archive', async function() {
    const name = `test-c293-zip-${Date.now()}`
    const subject = `c293-zip-${name}`
    try {
      await createFolder(name)
      await putMessage(name, subject)
      const uid = uidOfSubject(await folderView(name), subject)

      const res = await apiRaw('POST', `${soFolder(name)}/saveMessages`, { uids: [uid] })
      expect(res.status).withContext(`saveMessages returned ${res.status}`).toBe(200)
      expect(res.contentType).withContext('archive must be served as a zip').toContain('application/zip')
      expect(res.disposition).withContext('archive must be offered as an attachment').toContain('attachment')
      expect(res.buffer.subarray(0, 2).toString()).withContext('body must be a zip archive').toBe('PK')
      expect(res.buffer.includes(subject)).withContext('archived entry must be named after the message subject').toBeTrue()
    }
    finally {
      await deleteFolder(name).catch(() => {})
    }
  })

  it('exports a whole folder as a zip archive', async function() {
    const name = `test-c293-export-${Date.now()}`
    try {
      await createFolder(name)
      await putMessage(name, `c293-export-a-${name}`)
      await putMessage(name, `c293-export-b-${name}`)

      const res = await apiRaw('GET', `${soFolder(name)}/exportFolder`)
      expect(res.status).withContext(`exportFolder returned ${res.status}`).toBe(200)
      expect(res.contentType).withContext('export must be served as a zip').toContain('application/zip')
      expect(res.disposition).withContext('export filename must match the folder name').toContain(`${name}.zip`)
      expect(res.buffer.subarray(0, 2).toString()).withContext('body must be a zip archive').toBe('PK')
      expect(res.buffer.includes(`c293-export-a-${name}`)).withContext('export must contain the first message').toBeTrue()
      expect(res.buffer.includes(`c293-export-b-${name}`)).withContext('export must contain the second message').toBeTrue()
    }
    finally {
      await deleteFolder(name).catch(() => {})
    }
  })
})
