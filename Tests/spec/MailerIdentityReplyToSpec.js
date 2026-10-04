import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'

describe('MessageEditorController reply-to handling on identity switch', function() {
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

  function newEditor(replyTo) {
    const stateMessage = {
      editable: {
        from: identityA.full,
        replyTo: replyTo,
        to: [], cc: [], bcc: [],
        text: ''
      },
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
        SOGoMailComposeMessageType: 'text',
        SOGoMailSignaturePlacement: 'above',
        SOGoMailReplyPlacement: 'above'
      }
    }
    const editor = new MessageEditorController({ $on: function() {} }, {}, {}, {}, {}, {}, FileUploader,
                                                { isPopup: false }, { identities: [identityA, identityB] }, stateMessage,
                                                function() {}, function(value) { return value }, function() {},
                                                { toastPosition: 'bottom right' }, function() {}, {}, {}, {}, Preferences)
    editor.$onInit()
    return editor
  }

  it('takes the reply-to of the selected identity (#5984)', function() {
    const editor = newEditor('replies-a@example.com')
    editor.setFromIdentity({ full: identityB.full, replyTo: 'replies-b@example.org' })
    expect(editor.message.editable.replyTo).toBe('replies-b@example.org')
  })

  it('clears the previous reply-to when switching to an identity without one (#5984)', function() {
    const editor = newEditor('replies-a@example.com')
    editor.setFromIdentity({ full: identityB.full })
    expect(editor.message.editable.replyTo).toBe('')
  })

  it('leaves no reply-to when neither identity defines one', function() {
    const editor = newEditor('')
    editor.setFromIdentity({ full: identityB.full })
    expect(editor.message.editable.replyTo).toBe('')
  })
})
