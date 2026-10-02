import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'

describe('Mailer Message service', function() {
  let Message

  beforeAll(function() {
    const lodash = {
      forEach: function(collection, iteratee) {
        if (Array.isArray(collection)) {
          collection.forEach(function(value, index) { iteratee(value, index) })
        }
        else if (collection) {
          Object.keys(collection).forEach(function(key) { iteratee(collection[key], key) })
        }
      },
      map: function(collection, iteratee) {
        if (typeof iteratee === 'string') {
          return collection.map(function(value) { return value[iteratee] })
        }
        return collection.map(iteratee)
      },
      includes: function(collection, value) {
        return collection.indexOf(value) !== -1
      },
      indexOf: function(array, value) {
        return array.indexOf(value)
      },
      find: function(collection, predicate) {
        return collection.find(predicate)
      }
    }

    let factory
    const moduleChain = {
      constant: function() { return moduleChain },
      factory: function(name, factoryFunction) {
        factory = factoryFunction
        return moduleChain
      }
    }
    const angularStub = {
      extend: Object.assign,
      forEach: lodash.forEach,
      bind: function(self, fn) { return fn.bind(self) },
      isUndefined: function(value) { return value === undefined },
      isDefined: function(value) { return value !== undefined },
      isArray: Array.isArray,
      isObject: function(value) { return typeof value === 'object' && value !== null },
      isString: function(value) { return typeof value === 'string' },
      module: function() { return moduleChain }
    }

    const source = readFileSync(fileURLToPath(new URL('../../UI/WebServerResources/js/Mailer/Message.service.js', import.meta.url)), 'utf8')
    new Function('angular', '_', 'l', 'punycode',
                 `${source}
                  return angular.module('SOGo.MailerUI');`)(angularStub, lodash,
                                                           function(label) { return label },
                                                           { toUnicode: function(s) { return s }, toASCII: function(s) { return s } })
    const preferences = {
      defaults: {
        SOGoMailLabelsColors: {
          '$label1': ['Important', '#FF0000']
        }
      },
      avatar: function() { return '' }
    }
    const settings = {
      activeUser: function() { return '' }
    }
    class Resource {
      constructor() {}
    }
    Message = factory[factory.length - 1]({}, {}, console, settings,
                                  { NOT_LOADED: 0, DELAYED_LOADING: 1, LOADING: 2, LOADED: 3 },
                                  Resource, preferences)
  })

  const mailbox = { path: 'INBOX/test-6223', $account: { id: '0', identities: [] } }

  it('keeps the tags of a message instantiated from the parent window data (bug 6223)', function() {
    const openerMessage = new Message('0', mailbox, { uid: 1, flags: ['$label1'] })
    expect(openerMessage.flags).toEqual(['_$label1'])

    const popupMessage = new Message('0', mailbox, openerMessage.$omit({ privateAttributes: true }))
    expect(popupMessage.flags).toEqual(['_$label1'])
  })

  it('initializes flags to an empty array when the data has no flags', function() {
    const message = new Message('0', mailbox, { uid: 3 })
    expect(message.flags).toEqual([])
  })

  it('initializes flags to an empty array on lazy instantiation', function() {
    const message = new Message('0', mailbox, { uid: 4 }, true)
    expect(message.uid).toBe(4)
    expect(message.flags).toEqual([])
  })

  it('exposes the tags of the message through $omit for the popup window', function() {
    const message = new Message('0', mailbox, { uid: 5, flags: ['_$label1'] })
    const omitted = message.$omit({ privateAttributes: true })
    expect(omitted.flags).toEqual(['_$label1'])
  })
})
