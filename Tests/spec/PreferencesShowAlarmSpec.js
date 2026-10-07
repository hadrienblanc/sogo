import { readFileSync } from 'fs'

//
// Unit test of Preferences.showAlarm (bugs.sogo.nu #5779). The alarm toast
// handler assumed the payload of an event (startDate, isAllDay,
// localizedEndDate) and crashed on the payload of a task, where the
// reference date is exposed as dueDate and startDate is omitted when the
// task has no DTSTART. The service is loaded from its AngularJS source
// with stubbed dependencies; no SOGo server is required.

global.angular = global.angular || { isNumber: v => typeof v === 'number' }

global._ = global._ || {
  forEach: (collection, iteratee) => {
    if (!collection)
      return collection
    const keys = Array.isArray(collection)
      ? collection.map((value, index) => index)
      : Object.keys(collection)
    keys.forEach(key => iteratee(collection[key], key))
    return collection
  },
  toLower: text => String(text).toLowerCase(),
  map: (list, fn) => list.map(fn),
  indexOf: (list, item) => list.indexOf(item)
}
global.Element = global.Element || class Element {}
global.labels = global.labels || {}
global.clabels = global.clabels || {}

await import(new URL('../../UI/WebServerResources/js/Common/utils.js', import.meta.url).pathname)

function loadPreferences() {
  const registeredFactories = {}
  const angularModule = {
    factory: (name, factory) => { registeredFactories[name] = factory; return angularModule }
  }
  const angular = {
    extend: Object.assign,
    fromJson: text => JSON.parse(text),
    isDefined: value => value !== undefined,
    isUndefined: value => value === undefined,
    isString: value => typeof value === 'string',
    isArray: Array.isArray,
    module: () => angularModule
  }
  const source = readFileSync(
    new URL('../../UI/WebServerResources/js/Preferences/Preferences.service.js', import.meta.url),
    'utf8')
  new Function('angular', '_', 'l', 'window', source)(angular, global._, key => key, {})

  const factoryArray = registeredFactories['Preferences']
  const factory = factoryArray[factoryArray.length - 1]
  const harness = {}
  class Resource {
    fetch(module, action) {
      harness.lastFetch = { module: module, action: action }
      return {
        then: callback => { harness.fetchCallback = callback }
      }
    }
  }
  const factoryDeps = {
    window: {},
    document: [{
      getElementById: id => id === 'UserDefaults'
        ? { textContent: JSON.stringify({ SOGoDesktopNotifications: true }) }
        : null
    }],
    rootScope: {},
    q: {
      when: () => {
        const chainable = {
          then: callback => { harness.toastThen = callback; return chainable }
        }
        return chainable
      }
    },
    timeout: () => {},
    log: { error: () => {}, warn: () => {}, debug: () => {} },
    state: { get: () => null },
    mdDateLocale: {},
    mdToast: {
      show: config => { harness.toastConfig = config; return 'toast' },
      hide: () => {}
    },
    sgConstant: { toastPosition: 'bottom right' },
    settings: {
      activeUser: () => 'sogo-tests1',
      resourcesURL: () => '/SOGo.woa/WebServerResources'
    },
    gravatar: () => '',
    Resource: Resource,
    User: class {}
  }
  harness.preferences = factory(factoryDeps.window, factoryDeps.document,
                                factoryDeps.rootScope, factoryDeps.q,
                                factoryDeps.timeout, factoryDeps.log,
                                factoryDeps.state, factoryDeps.mdDateLocale,
                                factoryDeps.mdToast, factoryDeps.sgConstant,
                                factoryDeps.settings, factoryDeps.gravatar,
                                factoryDeps.Resource, factoryDeps.User)
  harness.preferences.createNotification =
    (id, summary, options) => { harness.notification = { id: id, summary: summary, body: options.body } }

  return harness
}

function fireAlarm(harness, payload) {
  harness.notification = undefined
  harness.toastConfig = undefined
  harness.preferences.showAlarm('personal/test-5779.ics')
  harness.fetchCallback(payload)
  harness.toastThen()
}

const isoDay = date =>
  date.getFullYear() + '-' +
  String(date.getMonth() + 1).padStart(2, '0') + '-' +
  String(date.getDate()).padStart(2, '0')

describe('Preferences showAlarm (bug 5779)', function() {

  const harness = loadPreferences()
  const today = new Date()
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)

  const dueOnlyTask = {
    component: 'vtodo',
    id: 'test-5779.ics',
    summary: 'test 5779 task',
    dueDate: isoDay(tomorrow) + 'T15:00:00+00:00',
    localizedDueDate: 'Friday, October 09, 2026',
    localizedDueTime: '15:00'
  }

  it('shows the toast for a task defined by a due date only', function() {
    fireAlarm(harness, dueOnlyTask)
    expect(harness.toastConfig)
      .withContext('the alarm toast must be displayed for tasks')
      .toBeDefined()
    expect(harness.notification.body)
      .withContext('notification body for a task due on another day')
      .toBe('Friday, October 09, 2026 15:00')
  })

  it('shows only the due time for a task due today', function() {
    const payload = {
      component: 'vtodo',
      id: 'test-5779.ics',
      summary: 'test 5779 task',
      dueDate: isoDay(today) + 'T15:00:00+00:00',
      localizedDueDate: 'today',
      localizedDueTime: '15:00'
    }
    fireAlarm(harness, payload)
    expect(harness.toastConfig)
      .withContext('the alarm toast must be displayed for tasks due today')
      .toBeDefined()
    expect(harness.notification.body)
      .withContext('notification body for a task due today')
      .toBe('15:00')
  })

  it('falls back to the start date for a task without due date', function() {
    const payload = {
      component: 'vtodo',
      id: 'test-5779.ics',
      summary: 'test 5779 task',
      startDate: isoDay(tomorrow) + 'T09:30:00+00:00',
      localizedStartDate: 'Friday, October 09, 2026',
      localizedStartTime: '09:30'
    }
    fireAlarm(harness, payload)
    expect(harness.toastConfig).toBeDefined()
    expect(harness.notification.body)
      .withContext('notification body for a start-only task')
      .toBe('Friday, October 09, 2026 09:30')
  })

  it('shows the toast for a task without any date', function() {
    fireAlarm(harness, { component: 'vtodo', id: 'test-5779.ics', summary: 'test 5779 task' })
    expect(harness.toastConfig)
      .withContext('the alarm toast must be displayed even without a date')
      .toBeDefined()
    expect(harness.notification.body).toBe('')
  })

  it('snoozes a task alarm through the view action', function() {
    fireAlarm(harness, dueOnlyTask)
    const scope = {}
    harness.toastConfig.controller(scope, 'personal/test-5779.ics')
    expect(scope.summary)
      .withContext('toast summary for a task alarm')
      .toBe('test 5779 task')
    scope.snooze()
    expect(harness.lastFetch.module)
      .withContext('snooze module for a task alarm')
      .toBe('Calendar/personal/test-5779.ics')
    expect(harness.lastFetch.action)
      .withContext('snooze action for a task alarm')
      .toBe('view?snoozeAlarm=10')
  })

  it('keeps the event period unchanged on a single day', function() {
    const payload = {
      component: 'vevent',
      id: 'test-5779.ics',
      summary: 'test 5779 event',
      startDate: isoDay(today) + 'T15:00:00+00:00',
      endDate: isoDay(today) + 'T16:00:00+00:00',
      isAllDay: false,
      localizedStartDate: 'today',
      localizedStartTime: '15:00',
      localizedEndDate: 'today',
      localizedEndTime: '16:00'
    }
    fireAlarm(harness, payload)
    expect(harness.toastConfig).toBeDefined()
    expect(harness.notification.body)
      .withContext('notification body for a single-day event')
      .toBe('15:00 - 16:00')
  })

  it('keeps the event period unchanged across days', function() {
    const payload = {
      component: 'vevent',
      id: 'test-5779.ics',
      summary: 'test 5779 event',
      startDate: isoDay(today) + 'T15:00:00+00:00',
      endDate: isoDay(tomorrow) + 'T16:00:00+00:00',
      isAllDay: false,
      localizedStartDate: 'today',
      localizedStartTime: '15:00',
      localizedEndDate: 'tomorrow',
      localizedEndTime: '16:00'
    }
    fireAlarm(harness, payload)
    expect(harness.notification.body)
      .withContext('notification body for a multi-day event')
      .toBe('today 15:00 - tomorrow 16:00')
  })
})
