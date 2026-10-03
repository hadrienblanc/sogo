import config from '../lib/config.js'
import Preferences from '../lib/Preferences.js'
import { default as WebDAV } from '../lib/WebDAV.js'
const fetch = globalThis.fetch

//
// Server side of bugs.sogo.nu #6152: inline SVG images are never rendered
// by SOGo's own message view. SVG documents can embed scripts, so an inline
// image/svg+xml part is kept as a downloadable attachment (link viewer),
// its cid reference is left unresolved in the HTML body, and the part is
// served as text/plain to neutralize any script when fetched directly.

const svgInlineMessage = `Message-ID: <test-6152-svg@sogo.local>
From: "SVG Sender" <test-6152@example.com>
To: ${config.username}@sogo.local
Subject: test-6152 svg inline signature
Date: Fri, 02 Oct 2026 10:00:00 +0200
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="=mixed"

--=mixed
Content-Type: multipart/alternative; boundary="=alt"

--=alt
Content-Type: text/plain; charset="us-ascii"
Content-Transfer-Encoding: 7bit

Test signature
--=alt
Content-Type: multipart/related; boundary="=rel"

--=rel
Content-Type: text/html; charset="us-ascii"
Content-Transfer-Encoding: 7bit

<html><body><p>Test signature</p><p><img src="cid:test-6152-svg@sogo.local" width="391" height="232"/></p></body></html>
--=rel
Content-Type: image/svg+xml; name="test-6152-sig.svg"
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename="test-6152-sig.svg"
Content-ID: <test-6152-svg@sogo.local>

PD94bWwgdmVyc2lvbj0iMS4wIiBzdGFuZGFsb25lPSJubyI/Pgo8c3ZnIHdpZHRoPSI3OTJweCIg
aGVpZ2h0PSI0NjRweCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xl
IGN4PSIyMDAiIGN5PSIyMDAiIHI9IjEwMCIgZmlsbD0icmdiKDgwLDE4OSw1NSkiLz48L3N2Zz4K
--=rel--
--=alt--
--=mixed--
`

describe('Mail inline SVG images (bug 6152)', function() {

  const mailbox = 'test-6152-svg'
  const resource = `/SOGo/dav/${config.username}/Mail/0/`

  let webdav
  let preferences
  let messageLocation

  const _putMessage = async function (path, message) {
    const response = await fetch(webdav.serverUrl + resource + `folder${path}`, {
      method: 'PUT',
      headers: { ...webdav.headers, 'Content-Type': 'message/rfc822' },
      body: message
    })
    expect(response.status)
      .withContext('HTTP status code when putting a message')
      .toBe(201)
    return response.headers.get('location')
  }

  const _fetchView = async function () {
    const uid = messageLocation.split('/').pop().replace(/\.eml$/, '')
    const viewURL = `/SOGo/so/${config.username}/Mail/0/folder${mailbox}/${uid}/view`
    const response = await fetch(preferences.serverUrl + viewURL, {
      method: 'GET',
      headers: { Cookie: await preferences.getAuthCookie() }
    })
    expect(response.status)
      .withContext('HTTP status code when fetching the message view')
      .toBe(200)
    return await response.json()
  }

  const _findPart = function (parts, contentType) {
    for (const part of parts) {
      const content = part.content
      if (part.contentType === contentType)
        return part
      if (Array.isArray(content)) {
        const found = _findPart(content, contentType)
        if (found)
          return found
      }
    }
    return undefined
  }

  beforeAll(async function() {
    webdav = new WebDAV(config.username, config.password)
    preferences = new Preferences(config.username, config.password)

    const [response] = await webdav.makeCollection(resource + mailbox)
    expect(response.status)
      .withContext('HTTP status code when creating the mailbox')
      .toBe(201)

    messageLocation = await _putMessage(mailbox, svgInlineMessage)
  })

  afterAll(async function() {
    await webdav.deleteObject(resource + `folder${mailbox}`)
  })

  it('does not resolve the cid reference of an inline SVG image', async function() {
    const data = await _fetchView()
    const htmlPart = _findPart([data.parts], 'text/html')

    expect(htmlPart)
      .withContext('the html part must be rendered')
      .toBeDefined()
    expect(htmlPart.content)
      .withContext('the img tag must stay in the body')
      .toContain('<img width="391" height="232"')
    expect(htmlPart.content)
      .withContext('the cid reference must not be resolved to a fetchable URL')
      .not.toContain('src="cid:')
    expect(htmlPart.content)
      .withContext('the img tag must not reference any URL of the SVG part')
      .not.toMatch(/<img[^>]*src=/)
  })

  it('presents an inline SVG image as a downloadable attachment', async function() {
    const data = await _fetchView()
    const svgPart = _findPart([data.parts], 'image/svg+xml')

    expect(svgPart)
      .withContext('the SVG part must be reported by the message view')
      .toBeDefined()
    expect(svgPart.type)
      .withContext('the SVG part must use the link viewer, never the image viewer')
      .toBe('UIxMailPartLinkViewer')
    expect(svgPart.content)
      .withContext('the SVG part must be downloadable as an attachment')
      .toContain('/asAttachment/')
  })

  it('serves an SVG part as text/plain to neutralize embedded scripts', async function() {
    const data = await _fetchView()
    const svgPart = _findPart([data.parts], 'image/svg+xml')
    const matches = svgPart.content.match(/href="([^"]*\/asAttachment\/[^"]*)"/)
    expect(matches)
      .withContext('the download link of the SVG part must be found')
      .toBeDefined()
    const viewURL = matches[1].replace('/asAttachment/', '/')

    const response = await fetch(preferences.serverUrl + viewURL, {
      method: 'GET',
      headers: { Cookie: await preferences.getAuthCookie() }
    })
    expect(response.status)
      .withContext('HTTP status code when fetching the SVG part')
      .toBe(200)
    expect(response.headers.get('content-type').split(';')[0].trim())
      .withContext('the SVG part must never be served as image/svg+xml')
      .toBe('text/plain')
  })

})
