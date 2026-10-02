import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'

describe('Mailer Account service', function() {
  const loadAccountService = function(punycodeRef) {
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
      module: function() { return moduleChain }
    }

    const source = readFileSync(fileURLToPath(new URL('../../UI/WebServerResources/js/Mailer/Account.service.js', import.meta.url)), 'utf8')
    new Function('angular', '_', 'punycode',
                 `${source}
                  return angular.module('SOGo.MailerUI');`)(angularStub, lodash, punycodeRef)

    class Resource {
      constructor() {}
    }
    return factory[factory.length - 1]({}, {}, console,
                                       { activeUser: function() { return '' }, folderURL: '' },
                                       Resource, {}, {}, {})
  }

  let Account, AccountWithoutPunycode

  beforeAll(function() {
    const punycodeSource = readFileSync(fileURLToPath(new URL('../../UI/WebServerResources/js/vendor/punycode.js', import.meta.url)), 'utf8')
    const punycode = new Function(`${punycodeSource}
                                   return punycode;`)()
    Account = loadAccountService(punycode)
    AccountWithoutPunycode = loadAccountService(undefined)
  })

  it('decodes the punycode representation of the account email for display (bug 6234)', function() {
    const account = new Account({ id: 0, name: 'ralf@xn--bcher-kva.example', identities: [] })
    expect(account.name).toBe('ralf@bücher.example')
  })

  it('leaves an ASCII account email untouched', function() {
    const account = new Account({ id: 0, name: 'user@example.com', identities: [] })
    expect(account.name).toBe('user@example.com')
  })

  it('is idempotent on an already decoded IDN account email', function() {
    const account = new Account({ id: 0, name: 'ralf@bücher.example', identities: [] })
    expect(account.name).toBe('ralf@bücher.example')
  })

  it('leaves a plain auxiliary account label untouched', function() {
    const account = new Account({ id: 1, name: 'Gmail', identities: [] })
    expect(account.name).toBe('Gmail')
  })

  it('keeps the account name untouched when the punycode library is unavailable', function() {
    const account = new AccountWithoutPunycode({ id: 0, name: 'ralf@xn--bcher-kva.example', identities: [] })
    expect(account.name).toBe('ralf@xn--bcher-kva.example')
  })

  it('does not fail when the account has no name', function() {
    const account = new Account({ id: 0, identities: [] })
    expect(account.name).toBeUndefined()
  })
})
