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

// Folder X (path "INBOX/X") is addressed as folderINBOX/folderX under Mail/0
const soFolder = name => `/so/${config.username}/Mail/0/folderINBOX/folder${name}`
const davFolder = name => `${BASE}/dav/${config.username}/Mail/0/folderINBOX/folder${name}`

async function listMailboxPaths() {
  const res = await api('GET', `/so/${config.username}/Mail/0/view`)
  expect(res.status).withContext(`mailbox tree returned ${res.status}`).toBe(200)
  const paths = []
  const walk = folder => {
    paths.push(folder.path)
    folder.children.forEach(walk)
  }
  res.data.mailboxes.forEach(walk)
  return paths
}

async function folderView(name) {
  const res = await api('GET', `${soFolder(name)}/view`)
  expect(res.status).withContext(`view of ${name} returned ${res.status}`).toBe(200)
  return res.data
}

function subjectsOf(view) {
  if (!view.headers || !view.headers[0])
    return []
  const [columns, ...rows] = view.headers
  const subjectIndex = columns.indexOf('Subject')
  return rows.map(row => row[subjectIndex])
}

async function putMessage(name, subject) {
  const message = [
    `Message-ID: <${subject}@c289.spec>`,
    `Date: ${new Date().toUTCString()}`,
    `From: E2E Spec <spec@sogo.local>`,
    `To: ${config.username}@sogo.local`,
    `Subject: ${subject}`,
    'Content-Type: text/plain; charset=utf-8',
    '',
    'Folder operations test body.'
  ].join('\r\n') + '\r\n'
  const res = await fetch(davFolder(name), {
    method: 'PUT',
    headers: { ...basicAuth(config.username, config.password), 'Content-Type': 'message/rfc822' },
    body: message
  })
  expect(res.status).withContext(`DAV PUT of message into ${name} returned ${res.status}`).toBe(201)
}

async function createFolder(parent, name) {
  const res = await api('POST', `${parent}/createFolder`, { name })
  expect(res.status).withContext(`createFolder returned ${res.status} (${JSON.stringify(res.data)})`).toBe(204)
}

async function deleteFolder(name) {
  const res = await api('POST', `${soFolder(name)}/delete`, { withoutTrash: true })
  expect(res.status).withContext(`delete of ${name} returned ${res.status}`).toBe(204)
}

describe('Mailer folder operations (so JSON API)', function() {
  beforeAll(async function() {
    jasmine.DEFAULT_TIMEOUT_INTERVAL = 30000
    session = await login()
  })

  it('creates a mailbox under INBOX and lists it', async function() {
    const name = `test-c289-create-${Date.now()}`
    await createFolder(`/so/${config.username}/Mail/0/folderINBOX`, name)

    const paths = await listMailboxPaths()
    expect(paths).withContext('new mailbox must appear in the tree').toContain(`INBOX/${name}`)

    const view = await folderView(name)
    expect(view.uids).withContext('a new mailbox must be empty').toEqual([])

    await deleteFolder(name)
    expect(await listMailboxPaths()).withContext('deleted mailbox must disappear from the tree').not.toContain(`INBOX/${name}`)
  })

  it('renames a mailbox and reports the new path', async function() {
    const name = `test-c289-rename-${Date.now()}`
    const renamed = `${name}-moved`
    await createFolder(`/so/${config.username}/Mail/0/folderINBOX`, name)

    const res = await api('POST', `${soFolder(name)}/save`, { name: renamed })
    expect(res.status).withContext(`rename via save returned ${res.status}`).toBe(200)
    expect(res.data.path).withContext('rename must report the new path').toBe(`INBOX/${renamed}`)

    const paths = await listMailboxPaths()
    expect(paths).withContext('renamed mailbox must appear under its new path').toContain(`INBOX/${renamed}`)
    expect(paths).withContext('old mailbox path must be gone').not.toContain(`INBOX/${name}`)

    await deleteFolder(renamed)
  })

  it('moves a message between mailboxes', async function() {
    const token = Date.now()
    const src = `test-c289-move-src-${token}`
    const dst = `test-c289-move-dst-${token}`
    const subject = `c289-move-${token}`
    try {
      await createFolder(`/so/${config.username}/Mail/0/folderINBOX`, src)
      await createFolder(`/so/${config.username}/Mail/0/folderINBOX`, dst)
      await putMessage(src, subject)

      const before = await folderView(src)
      expect(before.uids.length).withContext('message must land in the source mailbox').toBe(1)

      const res = await api('POST', `${soFolder(src)}/moveMessages`, {
        uids: before.uids, folder: `/0/folderINBOX/folder${dst}`
      })
      expect(res.status).withContext(`moveMessages returned ${res.status}`).toBe(200)

      expect(subjectsOf(await folderView(src))).withContext('source mailbox must be empty after the move').toEqual([])
      expect(subjectsOf(await folderView(dst))).withContext('moved message must be in the destination').toContain(subject)
    }
    finally {
      await deleteFolder(src).catch(() => {})
      await deleteFolder(dst).catch(() => {})
    }
  })

  it('copies a message to another mailbox', async function() {
    const token = Date.now()
    const src = `test-c289-copy-src-${token}`
    const dst = `test-c289-copy-dst-${token}`
    const subject = `c289-copy-${token}`
    try {
      await createFolder(`/so/${config.username}/Mail/0/folderINBOX`, src)
      await createFolder(`/so/${config.username}/Mail/0/folderINBOX`, dst)
      await putMessage(src, subject)

      const before = await folderView(src)
      expect(before.uids.length).withContext('message must land in the source mailbox').toBe(1)

      const res = await api('POST', `${soFolder(src)}/copyMessages`, {
        uids: before.uids, folder: `/0/folderINBOX/folder${dst}`
      })
      expect(res.status).withContext(`copyMessages returned ${res.status}`).toBe(200)

      expect(subjectsOf(await folderView(src))).withContext('original must stay in the source mailbox').toContain(subject)
      expect(subjectsOf(await folderView(dst))).withContext('copy must appear in the destination').toContain(subject)
    }
    finally {
      await deleteFolder(src).catch(() => {})
      await deleteFolder(dst).catch(() => {})
    }
  })

  it('deletes a mailbox immediately when withoutTrash is set', async function() {
    const name = `test-c289-delete-${Date.now()}`
    await createFolder(`/so/${config.username}/Mail/0/folderINBOX`, name)
    expect(await listMailboxPaths()).toContain(`INBOX/${name}`)

    await deleteFolder(name)

    const paths = await listMailboxPaths()
    expect(paths).withContext('deleted mailbox must be gone from the tree').not.toContain(`INBOX/${name}`)
    expect(paths.some(p => p.includes(`/${name}`))).withContext('no trace of the mailbox must remain (e.g. in Trash)').toBeFalse()
  })
})
