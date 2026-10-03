import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'

describe('Mailer MessageController popup flags sync', function() {
  let MessageController

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
      },
      difference: function(array, values) {
        return array.filter(function(value) { return values.indexOf(value) === -1 })
      }
    }

    let controller
    const moduleChain = {
      constant: function() { return moduleChain },
      controller: function(name, constructor) {
        controller = constructor
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

    const source = readFileSync(fileURLToPath(new URL('../../UI/WebServerResources/js/Mailer/MessageController.js', import.meta.url)), 'utf8')
    new Function('angular', '_', 'l',
                 `${source}
                  return angular.module('SOGo.MailerUI');`)(angularStub, lodash,
                                                            function(label) { return label })
    MessageController = controller
  })

  function instantiateController($window, stateMessage) {
    if (!stateMessage.toggleFlag)
      stateMessage.toggleFlag = function() {}
    const watchers = { collections: [], watches: [] }
    const $scope = {
      $watchCollection: function(expr, listener) { watchers.collections.push(listener) },
      $watch: function(expr, listener) { watchers.watches.push(listener) },
      $on: function() {}
    }
    const deps = {
      $window: $window,
      $scope: $scope,
      $q: {},
      $state: {},
      $mdMedia: function() { return false },
      $mdDialog: {},
      $mdPanel: {},
      sgConstant: {},
      stateAccounts: [],
      stateAccount: {},
      stateMailbox: { $id: function() { return '0/folderINBOX' } },
      stateMessage: stateMessage,
      sgHotkeys: { createHotkey: function(hotkey) { return hotkey }, registerHotkey: function() {} },
      encodeUriFilter: function(value) { return value },
      sgSettings: {},
      ImageGallery: { setMessage: function() {} },
      focus: function() {},
      Dialog: {},
      Preferences: { defaults: {} },
      Calendar: {},
      Component: {},
      Account: {},
      Mailbox: { $virtualMode: false },
      Message: {},
      AddressBook: {},
      Card: {}
    }
    const controller = {}
    MessageController.call(controller,
                           deps.$window, deps.$scope, deps.$q, deps.$state,
                           deps.$mdMedia, deps.$mdDialog, deps.$mdPanel, deps.sgConstant,
                           deps.stateAccounts, deps.stateAccount, deps.stateMailbox, deps.stateMessage,
                           deps.sgHotkeys, deps.encodeUriFilter, deps.sgSettings, deps.ImageGallery,
                           deps.focus, deps.Dialog, deps.Preferences, deps.Calendar,
                           deps.Component, deps.Account, deps.Mailbox, deps.Message,
                           deps.AddressBook, deps.Card)
    controller.$onInit()
    return { instance: controller, watchers: watchers }
  }

  function parentWindowWith(message) {
    const messageCtrl = {
      message: message,
      showFlags: false,
      service: { $timeout: function(fn) { fn() } }
    }
    const window = {
      opener: {
        $mailboxController: { selectedFolder: { $id: function() { return '0/folderINBOX' } } },
        $messageController: messageCtrl
      }
    }
    window.opener['$messageController'] = messageCtrl
    window.messageCtrl = messageCtrl
    return window
  }

  const tag = '_$label1'

  it('does not push the unloaded flags of a raw-message popup to the parent window (bug 6091)', function() {
    const parentMessage = { uid: 391, flags: [tag] }
    const popup = instantiateController(parentWindowWith(parentMessage),
                                        { uid: 391, flags: [], to: [], cc: [] })
    const popupFlagsWatcher = popup.watchers.collections[0]
    const unloadedFlags = []

    popupFlagsWatcher(unloadedFlags, unloadedFlags)

    expect(parentMessage.flags).toEqual([tag])
  })

  it('does not push the registration call of a popup holding the parent tags (bug 6223)', function() {
    const parentMessage = { uid: 391, flags: [tag] }
    const shared = parentMessage.flags
    const popup = instantiateController(parentWindowWith(parentMessage),
                                        { uid: 391, flags: shared, to: [], cc: [] })
    const popupFlagsWatcher = popup.watchers.collections[0]

    popupFlagsWatcher(shared, shared)

    expect(parentMessage.flags).toBe(shared)
  })

  it('syncs flags modified in the popup back to the parent window', function() {
    const parentMessage = { uid: 391, flags: [tag] }
    const parentWindow = parentWindowWith(parentMessage)
    const popup = instantiateController(parentWindow,
                                        { uid: 391, flags: [tag], to: [], cc: [] })
    const popupFlagsWatcher = popup.watchers.collections[0]

    popupFlagsWatcher(['_$label2'], [tag])

    expect(parentMessage.flags).toEqual(['_$label2'])
    expect(parentWindow.messageCtrl.showFlags).toBe(true)
  })

  it('issues no label request when the parent window watcher runs on untouched flags', function() {
    const tagOperations = []
    const parentMessage = {
      uid: 391,
      flags: [tag],
      addTag: function(t) { tagOperations.push(['add', t]) },
      removeTag: function(t) { tagOperations.push(['remove', t]) }
    }
    const popup = instantiateController(parentWindowWith(parentMessage),
                                        { uid: 391, flags: [], to: [], cc: [] })
    const popupFlagsWatcher = popup.watchers.collections[0]
    const parent = instantiateController({}, parentMessage)
    const parentFlagsWatcher = parent.watchers.collections[0]

    popupFlagsWatcher([], [])
    parentFlagsWatcher([tag], [tag])

    expect(tagOperations).toEqual([])
  })

  it('issues a remove request when a tag is removed from the popup', function() {
    const tagOperations = []
    const parentMessage = {
      uid: 391,
      flags: [tag],
      addTag: function(t) { tagOperations.push(['add', t]) },
      removeTag: function(t) { tagOperations.push(['remove', t]) }
    }
    const popup = instantiateController(parentWindowWith(parentMessage),
                                        { uid: 391, flags: [tag], to: [], cc: [] })
    const popupFlagsWatcher = popup.watchers.collections[0]
    const parent = instantiateController({}, parentMessage)
    const parentFlagsWatcher = parent.watchers.collections[0]

    popupFlagsWatcher([], [tag])
    parentFlagsWatcher([], [tag])

    expect(tagOperations).toEqual([['remove', tag]])
  })
})
