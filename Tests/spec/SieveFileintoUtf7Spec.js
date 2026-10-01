import net from 'net'
import { fetch } from 'cross-fetch'

import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import Preferences from '../lib/Preferences'
import ManageSieve from '../lib/ManageSieve'

const SUFFIX = String(Date.now())
const FOLDER_UTF7 = 'Probe' + SUFFIX + '/Unterst&APw-tzung'
const SIEVE_PATH = FOLDER_UTF7
const DECODED_PATH = 'Probe' + SUFFIX + '.Unterstützung'

const sendMail = function(subject) {
  const host = process.env.SOGO_SMTP_HOST || config.mailserver
  const port = process.env.SOGO_SMTP_PORT || 25

  return new Promise(function(resolve, reject) {
    const socket = net.createConnection({ host, port, timeout: 15000 })
    const commands = [
      'EHLO sogo-tests',
      `MAIL FROM:<sieve-utf7@example.org>`,
      `RCPT TO:<${config.username}@example.org>`,
      'DATA',
      `From: sieve-utf7@example.org\r\nTo: ${config.username}@example.org\r\nSubject: ${subject}\r\n\r\nutf7 fileinto probe\r\n.`
    ]
    let index = -1

    socket.on('data', function(data) {
      const lines = data.toString().split('\r\n').filter(l => l.length)
      const last = lines[lines.length - 1] || ''

      if (index === commands.length - 1) {
        socket.end()
        resolve()
        return
      }
      if (/^\d{3} /.test(last)) {
        index += 1
        socket.write(commands[index] + '\r\n')
      }
    })
    socket.on('error', reject)
    socket.on('timeout', function() {
      socket.destroy()
      reject(new Error('SMTP timeout'))
    })
  })
}

const mailboxMessageCount = function(mailbox) {
  const host = process.env.SOGO_IMAP_HOST || config.mailserver
  const port = process.env.SOGO_IMAP_PORT || 143

  return new Promise(function(resolve, reject) {
    const socket = net.createConnection({ host, port, timeout: 15000 })
    const tag = 'a' + Math.random().toString(16).slice(2, 8)
    const commands = [
      `${tag}1 LOGIN ${config.username} ${config.password}`,
      `${tag}2 SELECT "${mailbox}"`
    ]
    let index = -1
    let count = 0

    socket.on('data', function(data) {
      const chunk = data.toString()
      const exists = chunk.match(/\* (\d+) EXISTS/)
      if (exists)
        count = parseInt(exists[1], 10)

      if (chunk.indexOf(`${tag}2 `) >= 0) {
        socket.end()
        resolve(count)
        return
      }
      if (index < commands.length - 1 && (/^\* OK/.test(chunk) || chunk.indexOf(`${tag}1 `) >= 0)) {
        index += 1
        socket.write(commands[index] + '\r\n')
      }
    })
    socket.on('error', reject)
    socket.on('timeout', function() {
      socket.destroy()
      reject(new Error('IMAP timeout'))
    })
  })
}

describe('Sieve fileinto with non-ASCII folders', function() {
  const webdav = new WebDAV(config.username, config.password)
  const prefs = new Preferences(config.username, config.password)
  const manageSieve = new ManageSieve(config.username, config.username, config.password)

  beforeAll(async function() {
    jasmine.DEFAULT_TIMEOUT_INTERVAL = config.timeout || 60000
  })

  it('#5996 files into the decoded mailbox name', async function() {
    const parents = FOLDER_UTF7.split('/')
    const mailboxUrl = '/SOGo/dav/' + config.username + '/Mail/0/'
      + 'folder' + encodeURIComponent(parents[0]) + '/'
      + encodeURIComponent(parents[1]) + '/'
    await webdav.deleteObject(mailboxUrl).catch(() => {})
    const parentUrl = '/SOGo/dav/' + config.username + '/Mail/0/'
      + 'folder' + encodeURIComponent(parents[0]) + '/'
    await fetch(webdav.serverUrl + parentUrl,
                { method: 'MKCOL', headers: webdav.headers })
    const mkcol = await fetch(webdav.serverUrl + mailboxUrl,
                              { method: 'MKCOL', headers: webdav.headers })
    expect(mkcol.status)
      .withContext(`HTTP status of the mailbox creation`)
      .toEqual(201)

    const filters = [{
      active: 1,
      match: 'all',
      rules: [{ field: 'subject', operator: 'contains', value: 'utf7probe' }],
      actions: [{ method: 'fileinto', argument: SIEVE_PATH }]
    }]
    await prefs.setOrCreate('SOGoSieveFilters', filters)
    await prefs.setOrCreate('enabled', 0, ['defaults', 'Vacation'])
    await prefs.setOrCreate('forwardAddress', [], ['defaults', 'Forward'])
    const save = await prefs.save()
    expect(save.status)
      .withContext(`HTTP status of the preferences save`)
      .toEqual(200)

    await manageSieve.authenticate(true)
    const scripts = await manageSieve.listScripts()
    expect(scripts['sogo'])
      .withContext(`the sogo sieve script is the active one`)
      .toMatch(/ACTIVE/i)
    const script = await manageSieve.getScript('sogo')
    expect(script)
      .withContext(`the fileinto action holds the decoded UTF-8 folder name`)
      .toContain(`fileinto "${DECODED_PATH}"`)
    expect(script)
      .withContext(`the fileinto action no longer holds the mUTF-7 folder name`)
      .not.toContain('&APw-')

    await sendMail('utf7probe ' + Date.now())

    let delivered = false
    for (let i = 0; i < 10 && !delivered; i++) {
      await new Promise(r => setTimeout(r, 1000))
      delivered = (await mailboxMessageCount(SIEVE_PATH.replace('/', '.'))) > 0
    }
    expect(delivered)
      .withContext(`the message reached the target mailbox`)
      .toBe(true)
  })

  afterAll(async function() {
    await prefs.setOrCreate('SOGoSieveFilters', [])
    await prefs.save()
    const parents = FOLDER_UTF7.split('/')
    const mailboxUrl = '/SOGo/dav/' + config.username + '/Mail/0/'
      + 'folder' + encodeURIComponent(parents[0]) + '/'
      + encodeURIComponent(parents[1]) + '/'
    await webdav.deleteObject(mailboxUrl).catch(() => {})
    await webdav.deleteObject('/SOGo/dav/' + config.username + '/Mail/0/'
      + 'folder' + encodeURIComponent(parents[0]) + '/').catch(() => {})
  })
})
