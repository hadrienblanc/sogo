import config from '../lib/config.js'
import Preferences from '../lib/Preferences.js'
import { default as WebDAV } from '../lib/WebDAV.js'
const fetch = globalThis.fetch

const relatedWithInlineResource = `Message-ID: <test-6240-a@sogo.local>
From: "Related Sender" <related@example.com>
To: ${config.username}@sogo.local
Subject: test-6240 related with inline html resource
Date: Thu, 27 Aug 2026 11:45:00 +0200
MIME-Version: 1.0
Content-Type: multipart/related; type="multipart/alternative"; boundary="=_outer_6240"

--=_outer_6240
Content-Type: multipart/alternative; boundary="=_inner_6240"

--=_inner_6240
Content-Type: text/plain; charset=utf-8

This is the plain text body.

--=_inner_6240
Content-Type: text/html; charset=utf-8

<html><body><p>This is the HTML body.</p></body></html>

--=_inner_6240--

--=_outer_6240
Content-Type: text/html; charset=utf-8
Content-ID: <test-html-resource>
Content-Disposition: inline

<html><body><div style="position:fixed;top:0;left:0;z-index:9999;background:cyan">RELATED RESOURCE</div></body></html>

--=_outer_6240--
`

const relatedWithAttachmentResource = `Message-ID: <test-6240-b@sogo.local>
From: "Related Sender" <related@example.com>
To: ${config.username}@sogo.local
Subject: test-6240 related with attachment html resource
Date: Thu, 27 Aug 2026 11:45:00 +0200
MIME-Version: 1.0
Content-Type: multipart/related; type="multipart/alternative"; boundary="=_outer_6240"

--=_outer_6240
Content-Type: multipart/alternative; boundary="=_inner_6240"

--=_inner_6240
Content-Type: text/plain; charset=utf-8

This is the plain text body.

--=_inner_6240
Content-Type: text/html; charset=utf-8

<html><body><p>This is the HTML body.</p></body></html>

--=_inner_6240--

--=_outer_6240
Content-Type: text/html; charset=utf-8
Content-ID: <test-html-resource>
Content-Disposition: attachment; filename="resource.html"

<html><body><div>RELATED RESOURCE</div></body></html>

--=_outer_6240--
`

const relatedWithHtmlRootAndImage = `Message-ID: <test-6240-c@sogo.local>
From: "Related Sender" <related@example.com>
To: ${config.username}@sogo.local
Subject: test-6240 related with html root and cid image
Date: Thu, 27 Aug 2026 11:45:00 +0200
MIME-Version: 1.0
Content-Type: multipart/related; boundary="=_outer_6240"

--=_outer_6240
Content-Type: text/html; charset=utf-8

<html><body><p>This is the HTML body.</p><img src="cid:image@resource" /></body></html>

--=_outer_6240
Content-Type: image/png
Content-Transfer-Encoding: base64
Content-ID: <image@resource>
Content-Disposition: inline

iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==

--=_outer_6240--
`

const relatedWithStartParameter = `Message-ID: <test-6240-d@sogo.local>
From: "Related Sender" <related@example.com>
To: ${config.username}@sogo.local
Subject: test-6240 related with start parameter
Date: Thu, 27 Aug 2026 11:45:00 +0200
MIME-Version: 1.0
Content-Type: multipart/related; start="<html-root@resource>"; type="text/html"; boundary="=_outer_6240"

--=_outer_6240
Content-Type: image/png
Content-Transfer-Encoding: base64
Content-ID: <image-root@resource>
Content-Disposition: inline

iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==

--=_outer_6240
Content-Type: text/html; charset=utf-8
Content-ID: <html-root@resource>

<html><body><p>This is the HTML body.</p><img src="cid:image-root@resource" /></body></html>

--=_outer_6240--
`

describe('Mail multipart/related rendering (bug 6240)', function() {

  const mailbox = 'test-6240-related'
  const resource = `/SOGo/dav/${config.username}/Mail/0/`

  let webdav
  let preferences
  let messageLocations

  const _putMessage = async function(path, message) {
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

  const _fetchView = async function(location) {
    const uid = location.split('/').pop().replace(/\.eml$/, '')
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

  const _flattenParts = function(part, acc) {
    if (acc === undefined)
      acc = []
    if (Array.isArray(part.content))
      part.content.forEach(p => _flattenParts(p, acc))
    else
      acc.push(part)
    return acc
  }

  beforeAll(async function() {
    webdav = new WebDAV(config.username, config.password)
    preferences = new Preferences(config.username, config.password)

    const [response] = await webdav.makeCollection(resource + mailbox)
    expect(response.status)
      .withContext('HTTP status code when creating the mailbox')
      .toBe(201)

    messageLocations = {
      inlineResource: await _putMessage(mailbox + '/a.eml', relatedWithInlineResource),
      attachmentResource: await _putMessage(mailbox + '/b.eml', relatedWithAttachmentResource),
      htmlRoot: await _putMessage(mailbox + '/c.eml', relatedWithHtmlRootAndImage),
      startParameter: await _putMessage(mailbox + '/d.eml', relatedWithStartParameter)
    }
  })

  afterAll(async function() {
    await webdav.deleteObject(resource + `folder${mailbox}`)
  })

  it('renders only the root object of multipart/related as message body (inline resource)', async function() {
    const data = await _fetchView(messageLocations.inlineResource)
    const parts = _flattenParts(data.parts)

    const htmlParts = parts.filter(p => p.type == 'UIxMailPartHTMLViewer')
    expect(htmlParts.length)
      .withContext('only the root html part must be rendered as body')
      .toBe(1)
    expect(htmlParts[0].content).toContain('This is the HTML body.')

    const resourceParts = parts.filter(p => p.contentType == 'text/html' && p.type == 'UIxMailPartLinkViewer')
    expect(resourceParts.length)
      .withContext('the non-root inline text/html resource must be rendered as an attachment')
      .toBe(1)
    expect(parts.filter(p => p.type == 'UIxMailPartHTMLViewer' && p.content.indexOf('RELATED RESOURCE') > -1)
      .withContext('the related resource must not leak into the message body')
      .length).toBe(0)
  })

  it('keeps rendering non-root attachment resources of multipart/related as attachments', async function() {
    const data = await _fetchView(messageLocations.attachmentResource)
    const parts = _flattenParts(data.parts)

    expect(parts.filter(p => p.type == 'UIxMailPartHTMLViewer').length)
      .withContext('only the root html part must be rendered as body')
      .toBe(1)
    const resourceParts = parts.filter(p => p.contentType == 'text/html' && p.type == 'UIxMailPartLinkViewer')
    expect(resourceParts.length).toBe(1)
    expect(resourceParts[0].filename).toContain('resource.html')
  })

  it('keeps rendering the html root of multipart/related as message body', async function() {
    const data = await _fetchView(messageLocations.htmlRoot)
    const parts = _flattenParts(data.parts)

    const htmlParts = parts.filter(p => p.type == 'UIxMailPartHTMLViewer')
    expect(htmlParts.length).toBe(1)
    expect(htmlParts[0].content).toContain('This is the HTML body.')

    expect(parts.filter(p => p.contentType == 'image/png').length)
      .withContext('the related image must stay downloadable as an attachment')
      .toBe(1)
  })

  it('honours the start parameter of multipart/related when selecting the root object', async function() {
    const data = await _fetchView(messageLocations.startParameter)
    const parts = _flattenParts(data.parts)

    const htmlParts = parts.filter(p => p.type == 'UIxMailPartHTMLViewer')
    expect(htmlParts.length)
      .withContext('the part designated by start must be rendered as body')
      .toBe(1)
    expect(htmlParts[0].content).toContain('This is the HTML body.')

    expect(parts.filter(p => p.type == 'UIxMailPartHTMLViewer' && p.content.indexOf('image/png data') > -1).length)
      .toBe(0)
  })

})
