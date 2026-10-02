import config from '../lib/config.js'
import Preferences from '../lib/Preferences.js'
import { default as WebDAV } from '../lib/WebDAV.js'
const fetch = globalThis.fetch

const wordMessage = `Message-ID: <test-6180-word@sogo.local>
From: "Word Sender" <word@example.com>
To: ${config.username}@sogo.local
Subject: test-6180 Word HTML mail
Date: Fri, 02 Oct 2026 10:00:00 +0200
MIME-Version: 1.0
Content-Type: text/html; charset="us-ascii"
Content-Transfer-Encoding: 7bit

<html xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word">

<head>
<meta http-equiv=Content-Type content="text/html; charset=us-ascii">
<meta name=ProgId content=Word.Document>
<style>
<!--
@import url("https://fonts.example.com/css?family=Calibri");
p.MsoNormal, li.MsoNormal, div.MsoNormal
\t{margin:0cm;
\tmargin-bottom:.0001pt;
\tmso-pagination:widow-orphan;
\tfont-size:11.0pt;
\tfont-family:"Calibri",sans-serif;}
@font-face
\t{font-family:"Cambria Math";
\tpanose-1:2 4 5 3 5 4 6 3 2 4;}
@page WordSection1
\t{size:612.0pt 792.0pt;
\tmargin:72.0pt 72.0pt 72.0pt 72.0pt;}
div.WordSection1
\t{page:WordSection1;}
-->
</style>
</head>

<body lang=EN-US link=blue vlink="#954F72" style='word-wrap:break-word'>

<div class=WordSection1>

<p class=MsoNormal>Hello from Word, first paragraph.</p>

<p class=MsoNormal><o:p>&nbsp;</o:p></p>

<p class=MsoNormal>Second paragraph after a paragraph mark spacer.</p>

</div>

</body>

</html>
`

describe('Mail HTML rendering (bug 6180)', function() {

  const mailbox = 'test-6180-rendering'
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
    const uid = messageLocation.split('/').pop().replace(/\\.eml$/, '')
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

  beforeAll(async function() {
    webdav = new WebDAV(config.username, config.password)
    preferences = new Preferences(config.username, config.password)

    const [response] = await webdav.makeCollection(resource + mailbox)
    expect(response.status)
      .withContext('HTTP status code when creating the mailbox')
      .toBe(201)

    messageLocation = await _putMessage(mailbox, wordMessage)
  })

  afterAll(async function() {
    await webdav.deleteObject(resource + `folder${mailbox}`)
  })

  it('keeps the CSS rules of Word emails (brace-less at-rule must not swallow them)', async function() {
    const data = await _fetchView()
    const content = data.parts.content

    expect(content)
      .withContext('the p.MsoNormal rule must survive the @import statement')
      .toContain('.SOGoHTMLMail-CSS-Delimiter p.MsoNormal')
    expect(content)
      .withContext('the Word margin reset must be applied with !important')
      .toContain('margin:0cm !important')
    expect(content)
      .withContext('mso properties must be passed through')
      .toContain('mso-pagination:widow-orphan !important')
    expect(content)
      .withContext('@font-face blocks must stay dropped')
      .not.toContain('Cambria Math')
    expect(content)
      .withContext('@page blocks must stay dropped')
      .not.toContain('size:612.0pt')
  })

  it('does not turn Office paragraph marks into real paragraphs', async function() {
    const data = await _fetchView()
    const content = data.parts.content

    expect(content)
      .withContext('Office paragraph marks must not become paragraphs')
      .not.toContain('<p>&#160;</p>')
    expect(content)
      .withContext('the spacer content must stay inline')
      .toContain('&#160;')
    expect(content)
      .withContext('the Word paragraphs must be rendered')
      .toContain('<p class="MsoNormal">')
  })

})
