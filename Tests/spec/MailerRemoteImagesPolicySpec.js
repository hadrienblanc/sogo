import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'

//
// Unit test of the remote inline images policy applied by
// Message.prototype.$content() (bugs.sogo.nu #6170): remote images are
// blocked in the Junk folder whatever the preference says, and the
// "known" preference only unblocks them when the server reported the
// sender as present in the address book. The service is loaded from its
// AngularJS source with stubbed dependencies; no SOGo server is required.

const REMOTE_IMAGE = 'http://tracker.example/pixel.png'

describe('Message remote inline images policy (bug 6170)', function() {

  let MessageConstructor

  const lodash = {
    forEach: function(collection, iteratee) {
      if (!collection)
        return collection
      if (Array.isArray(collection))
        collection.forEach(iteratee)
      else
        Object.keys(collection).forEach(function(key) { iteratee(collection[key], key) })
      return collection
    },
    map: function(collection, iteratee) {
      if (!collection)
        return []
      if (typeof iteratee == 'string')
        return collection.map(function(item) { return item[iteratee] })
      return collection.map(iteratee)
    },
    find: function(collection, predicate) {
      return collection.find(predicate)
    },
    indexOf: function(array, value) {
      return array.indexOf(value)
    }
  }

  const angularStub = {
    extend: Object.assign,
    bind: function(self, fn) {
      return fn.bind(self)
    },
    forEach: lodash.forEach,
    isDefined: function(value) { return value !== undefined },
    isUndefined: function(value) { return value === undefined },
    isString: function(value) { return typeof value == 'string' },
    isArray: function(value) { return Array.isArray(value) },
    element: function(node) {
      return {
        attr: function(name, value) {
          if (typeof value == 'undefined')
            return REMOTE_IMAGE
          node.rewritten = true
        },
        removeAttr: function() {
          node.rewritten = true
        }
      }
    }
  }

  const documentStub = {
    createElement: function() {
      const element = {
        html: '',
        rewritten: false,
        querySelectorAll: function(selector) {
          return selector == '[unsafe-src]' ? [element] : []
        }
      }
      Object.defineProperty(element, 'innerHTML', {
        get: function() {
          return element.rewritten
            ? element.html.replace(/unsafe-src=/g, 'src=')
            : element.html
        },
        set: function(value) {
          element.html = value
        }
      })
      return element
    }
  }

  beforeAll(function() {
    let factoryFunction
    const moduleChain = {
      constant: function() { return moduleChain },
      factory: function(name, annotatedFactory) {
        factoryFunction = annotatedFactory[annotatedFactory.length - 1]
        return moduleChain
      }
    }
    angularStub.module = function() { return moduleChain }

    const source = readFileSync(fileURLToPath(new URL('../../UI/WebServerResources/js/Mailer/Message.service.js', import.meta.url)), 'utf8')
    new Function('angular', '_', 'punycode', 'l', 'document', source)(
      angularStub, lodash,
      { toUnicode: function(address) { return address }, toASCII: function(address) { return address } },
      function(label) { return label },
      documentStub)
    MessageConstructor = factoryFunction
  })

  const messageWithPolicy = function(options) {
    const preferences = {
      defaults: {
        SOGoMailDisplayRemoteInlineImages: options.preference || 'never'
      },
      avatar: function() { return '' }
    }
    const Message = MessageConstructor.call({},
                                         { defer: function() {} },
                                         function(fn) { fn() },
                                         { debug: function() {} },
                                         { activeUser: function() { return '/SOGo/so/user' } },
                                         { NOT_LOADED: 0 },
                                         function Resource() {},
                                         preferences)

    const mailbox = options.mailbox === null
          ? undefined
          : Object.assign(
            { type: options.mailbox || 'inbox',
              getHighlightWords: function() { return [] },
              $account: { identities: [] } },
            options.mailboxExtras)
    const message = new Message('0', mailbox, {
      uid: 42,
      senderInAddressBook: options.senderInAddressBook,
      parts: {
        type: 'UIxMailPartHTMLViewer',
        content: `<body><img unsafe-src="${REMOTE_IMAGE}"/></body>`
      }
    })
    if (options.clickLoadImages)
      message.loadUnsafeContent()

    return message
  }

  const remoteImagesDisplayed = function(message) {
    const parts = message.$content()
    return parts[0].content.indexOf(`<img src="${REMOTE_IMAGE}"`) > -1
  }

  const remoteImagesBlocked = function(message) {
    const parts = message.$content()
    return parts[0].content.indexOf(`<img unsafe-src="${REMOTE_IMAGE}"`) > -1
  }

  it('displays remote images outside the Junk folder when preference is "always"',
     function() {
       const message = messageWithPolicy({ preference: 'always', mailbox: 'inbox' })
       expect(remoteImagesDisplayed(message))
         .withContext('"always" must unblock remote images outside Junk')
         .toBe(true)
     })

  it('blocks remote images in the Junk folder even when preference is "always"',
     function() {
       const message = messageWithPolicy({ preference: 'always', mailbox: 'junk' })
       expect(remoteImagesBlocked(message))
         .withContext('"always" must be ignored in the Junk folder')
         .toBe(true)
       expect(message.$hasUnsafeContent)
         .withContext('the "Load Images" banner must stay available in Junk')
         .toBeTruthy()
     })

  it('displays remote images when preference is "known" and the sender is in the address book',
     function() {
       const message = messageWithPolicy({ preference: 'known', mailbox: 'inbox',
                                            senderInAddressBook: true })
       expect(remoteImagesDisplayed(message))
         .withContext('"known" must unblock remote images for address book senders')
         .toBe(true)
     })

  it('blocks remote images when preference is "known" and the sender is not in the address book',
     function() {
       const message = messageWithPolicy({ preference: 'known', mailbox: 'inbox',
                                            senderInAddressBook: false })
       expect(remoteImagesBlocked(message))
         .withContext('"known" must keep blocking unknown senders')
         .toBe(true)
     })

  it('blocks remote images in the Junk folder when preference is "known" and the sender is in the address book',
     function() {
       const message = messageWithPolicy({ preference: 'known', mailbox: 'junk',
                                            senderInAddressBook: true })
       expect(remoteImagesBlocked(message))
         .withContext('"known" must be ignored in the Junk folder')
         .toBe(true)
     })

  it('blocks remote images when preference is "never"',
     function() {
       const message = messageWithPolicy({ preference: 'never', mailbox: 'inbox' })
       expect(remoteImagesBlocked(message))
         .withContext('"never" must keep blocking remote images')
         .toBe(true)
     })

  it('displays remote images on explicit user request in the Junk folder whatever the preference',
     function() {
       const message = messageWithPolicy({ preference: 'never', mailbox: 'junk',
                                            clickLoadImages: true })
       expect(remoteImagesDisplayed(message))
         .withContext('clicking "Load Images" must always work, even in Junk')
         .toBe(true)
     })

  it('defaults to blocking when no preference value is set',
     function() {
       const message = messageWithPolicy({ preference: undefined, mailbox: 'inbox' })
       expect(remoteImagesBlocked(message))
         .withContext('a missing preference must behave like "never"')
         .toBe(true)
     })

})
