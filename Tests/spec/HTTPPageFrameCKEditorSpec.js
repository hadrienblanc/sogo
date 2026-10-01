import { fetch } from 'cross-fetch'
import config from '../lib/config'

const FIREFOX_ANDROID_UA = 'Mozilla/5.0 (Android 16; Mobile; rv:149.0) Gecko/149.0 Firefox/149.0'
const CHROME_ANDROID_UA = 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36'
const FIREFOX_DESKTOP_UA = 'Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/149.0 Firefox/149.0'

const serverUrl = `http://${config.hostname}:${config.port}`

async function getAuthCookie() {
  const response = await fetch(`${serverUrl}/SOGo/connect`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userName: config.username, password: config.password })
  })
  if (response.status != 200)
    throw new Error(`Can't authenticate as ${config.username} (HTTP ${response.status})`)
  const values = response.headers.get('set-cookie').split(/, /)
  const wanted = []
  for (const v of values) {
    const m = /^(0xHIGHFLYxSOGo|XSRF-TOKEN)=[^;]*/.exec(v)
    if (m) wanted.push(m[0])
  }
  return wanted.join('; ')
}

async function fetchMailView(authCookie, userAgent) {
  const response = await fetch(`${serverUrl}/SOGo/so/${config.username}/Mail/view`, {
    method: 'GET',
    headers: {
      Cookie: authCookie,
      'User-Agent': userAgent
    }
  })
  const body = await response.text()
  return { status: response.status, body }
}

describe('page frame ckeditor user agent override (bug 6189)', function() {

  beforeAll(async function() {
    this.authCookie = await getAuthCookie()
  })

  it('serves a desktop Gecko user agent override on the mail page for Firefox on Android', async function() {
    const { status, body } = await fetchMailView(this.authCookie, FIREFOX_ANDROID_UA)
    expect(status).withContext('Mail view must be served').toEqual(200)
    expect(body).withContext('the override must redefine navigator.userAgent before CKEditor loads')
      .toContain("Object.defineProperty(navigator, 'userAgent'")
    expect(body).withContext('the overridden user agent must be a desktop Firefox one')
      .toContain('Mozilla/5.0 (X11; Linux x86_64) Gecko/149 Firefox/149')
    expect(body).not.toContain("return 'Mozilla/5.0 (Android")
  })

  it('does not override the user agent for Chrome on Android', async function() {
    const { status, body } = await fetchMailView(this.authCookie, CHROME_ANDROID_UA)
    expect(status).withContext('Mail view must be served').toEqual(200)
    expect(body).not.toContain("Object.defineProperty(navigator, 'userAgent'")
  })

  it('does not override the user agent for desktop Firefox', async function() {
    const { status, body } = await fetchMailView(this.authCookie, FIREFOX_DESKTOP_UA)
    expect(status).withContext('Mail view must be served').toEqual(200)
    expect(body).not.toContain("Object.defineProperty(navigator, 'userAgent'")
  })
})
