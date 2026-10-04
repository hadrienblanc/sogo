import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'

describe('MessageEditorController signature handling on identity switch', function() {
  let MessageEditorController

  const lodash = {
    find: function(collection, predicate) {
      return collection.find(predicate)
    }
  }

  beforeAll(function() {
    let editorController
    const moduleChain = {
      controller: function(name, controller) {
        if (name == 'MessageEditorController')
          editorController = controller
        return moduleChain
      }
    }
    const angularStub = {
      isDefined: function(value) { return value !== undefined },
      isUndefined: function(value) { return value === undefined },
      isNumber: function(value) { return typeof value == 'number' },
      module: function() { return moduleChain }
    }
    const source = readFileSync(fileURLToPath(new URL('../../UI/WebServerResources/js/Mailer/MessageEditorController.js', import.meta.url)), 'utf8')
    new Function('angular', '_', 'screen', `${source}
                                  return angular.module('SOGo.MailerUI');`)(angularStub, lodash,
                                                                            { orientation: { type: 'landscape-primary' } })
    MessageEditorController = editorController
  })

  const identityA = { full: 'Robert Frost <robert@example.com>' }
  const identityB = { full: 'Bob Burton <bob@example.org>' }
  const identityShared = { full: 'Shared mailbox <shared@example.com>' }
  const signatureA = 'Robert Frost\nCTO (Example) +33 1 23 45 67 89\nhttps://example.com/?from=sig'
  const signatureB = 'Bob Burton\nhttps://bob.example.org/'
  const signatureAHtml = '<b>Robert Frost</b><br />CTO (Example) +33 1 23 45 67 89<br />https://example.com/?from=sig'
  const signatureBHtml = '<i>Bob Burton</i><br />https://bob.example.org/'

  function newEditor(text, options) {
    options = options || {}
    const identities = options.identities ||
          [ { full: identityA.full, signature: options.signatureA || signatureA },
            { full: identityB.full, signature: options.signatureB || signatureB } ]
    const stateMessage = {
      editable: {
        from: identityA.full,
        to: [], cc: [], bcc: [],
        text: text
      },
      origin: options.origin,
      $absolutePath: function() { return '/dav/drafts/123' }
    }
    class FileUploader {
      constructor(uploaderOptions) { this.url = uploaderOptions.url }
    }
    const Preferences = {
      defaults: {
        SOGoMailAutoSave: 0,
        SOGoMailUseSignatureOnNew: 1,
        SOGoMailUseSignatureOnForward: 1,
        SOGoMailUseSignatureOnReply: 1,
        SOGoMailComposeMessageType: options.composeType || 'text',
        SOGoMailSignaturePlacement: options.signaturePlacement || 'above',
        SOGoMailReplyPlacement: options.replyPlacement || 'above'
      }
    }
    const editor = new MessageEditorController({ $on: function() {} }, {}, {}, {}, {}, {}, FileUploader,
                                                { isPopup: false }, { identities: identities }, stateMessage,
                                                function() {}, function(value) { return value }, function() {},
                                                { toastPosition: 'bottom right' }, function() {}, {}, {}, {}, Preferences)
    editor.$onInit()
    return editor
  }

  it('removes the previous signature when switching to an identity without signature (#6214)', function() {
    const editor = newEditor('\n\n-- \n' + signatureA, { composeType: 'text' })
    editor.setFromIdentity({ full: identityShared.full })
    expect(editor.message.editable.text).toBe('')
  })

  it('replaces the previous signature by the new identity signature in plain text (#6214)', function() {
    const editor = newEditor('\n\n-- \n' + signatureA, { composeType: 'text' })
    editor.setFromIdentity({ full: identityB.full, signature: signatureB })
    expect(editor.message.editable.from).toBe(identityB.full)
    expect(editor.message.editable.text).toBe('\n\n-- \n' + signatureB)
  })

  it('replaces the signature placed below the message', function() {
    const editor = newEditor('Hello\n\n-- \n' + signatureA,
                             { composeType: 'text', signaturePlacement: 'below' })
    editor.setFromIdentity({ full: identityB.full, signature: signatureB })
    expect(editor.message.editable.text).toBe('Hello\n\n-- \n' + signatureB)
  })

  it('replaces the previous signature in an untouched HTML draft', function() {
    const editor = newEditor('<br /><br />--&nbsp;<br />' + signatureAHtml,
                             { composeType: 'html', signatureA: signatureAHtml, signatureB: signatureBHtml })
    editor.setFromIdentity({ full: identityB.full, signature: signatureBHtml })
    expect(editor.message.editable.text).toBe('<br /><br />--&nbsp;<br />' + signatureBHtml)
  })

  it('replaces the previous signature after the HTML editor normalized the draft (#6168, #6214)', function() {
    const editor = newEditor('<p>Typed text</p><p><br><br>--&nbsp;<br>' +
                             '<b>Robert Frost</b><br>CTO (Example) +33 1 23 45 67 89<br>https://example.com/?from=sig</p>',
                             { composeType: 'html', signatureA: signatureAHtml, signatureB: signatureBHtml })
    editor.setFromIdentity({ full: identityB.full, signature: signatureBHtml })
    expect(editor.message.editable.text).toBe('<p>Typed text</p><br /><br />--&nbsp;<br />' + signatureBHtml)
  })

  it('removes the normalized HTML signature when switching to an identity without signature (#6214)', function() {
    const editor = newEditor('<p>Typed text</p><p><br><br>--&nbsp;<br>' +
                             '<b>Robert Frost</b><br>CTO (Example) +33 1 23 45 67 89<br>https://example.com/?from=sig</p>',
                             { composeType: 'html', signatureA: signatureAHtml })
    editor.setFromIdentity({ full: identityShared.full })
    expect(editor.message.editable.text).toBe('<p>Typed text</p>')
  })

  it('appends the signature when no previous signature is found in the message', function() {
    const editor = newEditor('Hello', { composeType: 'text' })
    editor.setFromIdentity({ full: identityB.full, signature: signatureB })
    expect(editor.message.editable.text).toBe('Hello\n\n-- \n' + signatureB)
  })

  it('inserts the signature above the quoted message on replies', function() {
    const editor = newEditor('\n\nOn January 1, 2026 at 10:00, a@example.com wrote:\n\n> quoted',
                             { composeType: 'text', origin: { action: 'reply' } })
    editor.setFromIdentity({ full: identityB.full, signature: signatureB })
    expect(editor.message.editable.text)
      .toBe('\n\n\n-- \n' + signatureB +
            '\nOn January 1, 2026 at 10:00, a@example.com wrote:\n\n> quoted')
  })

  it('inserts the signature above the moz-cite-prefix marker on HTML replies (#5993)', function() {
    const editor = newEditor('<br/><br/><div class="moz-cite-prefix">On January 1, 2026 at 10:00, a@example.com wrote:</div><br/><br/><blockquote type="cite" cite="a@example.com">quoted</blockquote>',
                             { composeType: 'html', origin: { action: 'reply' },
                               signatureB: signatureBHtml })
    editor.setFromIdentity({ full: identityB.full, signature: signatureBHtml })
    expect(editor.message.editable.text)
      .toBe('<br /><br />--&nbsp;<br />' + signatureBHtml +
            '<br/><br/><div class="moz-cite-prefix">On January 1, 2026 at 10:00, a@example.com wrote:</div><br/><br/><blockquote type="cite" cite="a@example.com">quoted</blockquote>')
  })
})
