import { readFileSync } from 'fs'

//
// Unit test of the recipients assembled by ComponentController when
// composing a mail to all participants of an event (bugs.sogo.nu #6183).
// The controller is loaded from its AngularJS source with stubbed
// dependencies; no SOGo server is required.

function loadComponentController() {
  const registeredControllers = {}
  const angularModule = {
    controller: (name, fn) => { registeredControllers[name] = fn; return angularModule }
  }
  const angular = {
    extend: Object.assign,
    element: () => ({}),
    module: () => angularModule
  }
  const _ = {
    map: (collection, iteratee) => collection.map(iteratee),
    find: (collection, predicate) => collection.find(predicate),
    findIndex: (collection, predicate) => collection.findIndex(
      typeof predicate === 'function' ? predicate : item => {
        for (const key in predicate)
          if (item[key] !== predicate[key])
            return false
        return true
      }
    )
  }
  const source = readFileSync(
    new URL('../../UI/WebServerResources/js/Scheduler/ComponentController.js', import.meta.url),
    'utf8')
  new Function('angular', '_', 'document', source)(angular, _, { body: {} })
  return registeredControllers['ComponentController']
}

function newControllerWithCapturedMessage(component) {
  let message = { editable: {} }
  const account = {
    id: 0,
    $getMailboxes: () => Promise.resolve([]),
    $newMessage: () => Promise.resolve(message)
  }
  const Account = { $findAll: () => Promise.resolve([account]) }
  const $mdDialog = { show: () => {} }
  const $q = { defer: () => ({ resolve: () => {}, promise: Promise.resolve() }) }
  const noop = () => {}
  const Controller = loadComponentController()
  const controller = new Controller(
    {}, {}, $q, $mdDialog, {}, {}, noop, noop, noop, Account, component)
  controller.$onInit()
  controller.mailMessage = () => {
    const event = { preventDefault: noop, stopPropagation: noop }
    controller.newMessageWithAllRecipients(event)
    return new Promise(resolve => setTimeout(() => resolve(message), 10))
  }
  return controller
}

describe('ComponentController mail recipients (bug 6183)', function() {

  it('includes the organizer when composing to all participants of an event the user is invited to', async function() {
    const controller = newControllerWithCapturedMessage({
      summary: 'test 6183',
      organizer: { name: 'Sogo Tests One', email: 'sogo-tests1@sogo.local' },
      attendees: [
        { name: 'Sogo Tests Two', email: 'sogo-tests2@sogo.local' },
        { name: 'Sogo Tests Three', email: 'sogo-tests3@sogo.local' }
      ]
    })

    const message = await controller.mailMessage()

    expect(message.editable.to).toEqual([
      'Sogo Tests One <sogo-tests1@sogo.local>',
      'Sogo Tests Two <sogo-tests2@sogo.local>',
      'Sogo Tests Three <sogo-tests3@sogo.local>'
    ])
    expect(message.editable.subject).toEqual('test 6183')
  })

  it('does not duplicate the organizer when it also chairs the event', async function() {
    const controller = newControllerWithCapturedMessage({
      summary: 'test 6183',
      organizer: { name: 'Sogo Tests One', email: 'sogo-tests1@sogo.local' },
      attendees: [
        { name: 'Sogo Tests One', email: 'sogo-tests1@sogo.local' },
        { name: 'Sogo Tests Two', email: 'sogo-tests2@sogo.local' }
      ]
    })

    const message = await controller.mailMessage()

    expect(message.editable.to).toEqual([
      'Sogo Tests One <sogo-tests1@sogo.local>',
      'Sogo Tests Two <sogo-tests2@sogo.local>'
    ])
  })

  it('falls back to the attendees only when the event has no organizer', async function() {
    const controller = newControllerWithCapturedMessage({
      summary: 'test 6183',
      organizer: undefined,
      attendees: [
        { name: 'Sogo Tests Two', email: 'sogo-tests2@sogo.local' }
      ]
    })

    const message = await controller.mailMessage()

    expect(message.editable.to).toEqual([
      'Sogo Tests Two <sogo-tests2@sogo.local>'
    ])
  })

})
