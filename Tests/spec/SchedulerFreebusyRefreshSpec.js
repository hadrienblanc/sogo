import { readFileSync } from 'fs'

//
// Unit test of the freebusy refresh signal watched by the sgFreebusy directive
// when attendees are added or removed (bugs.sogo.nu #6079).
// The real AngularJS sources are loaded with stubbed dependencies; no SOGo
// server is required.

function loadSources() {
  const registered = { factories: {}, directives: {}, constants: {} }
  const angularModule = {
    constant: (name, value) => { registered.constants[name] = value; return angularModule },
    factory: (name, fn) => { registered.factories[name] = fn; return angularModule },
    directive: (name, fn) => { registered.directives[name] = fn; return angularModule }
  }
  const angular = {
    extend: Object.assign,
    module: () => angularModule,
    isDefined: value => value !== undefined,
    isUndefined: value => value === undefined
  }
  const _ = {
    forEach: (collection, iteratee) => {
      if (!collection)
        return collection
      if (Array.isArray(collection))
        collection.forEach(iteratee)
      else
        Object.keys(collection).forEach(key => iteratee(collection[key], key))
      return collection
    },
    map: (collection, iteratee) => {
      const fn = typeof iteratee === 'string' ? item => item[iteratee] : iteratee
      return collection ? collection.map(fn) : []
    },
    find: (collection, predicate) => collection ? collection.find(predicate) : undefined,
    findIndex: (collection, predicate) => {
      if (!collection)
        return -1
      const fn = typeof predicate === 'function' ? predicate : item => {
        for (const key in predicate)
          if (item[key] !== predicate[key])
            return false
        return true
      }
      return collection.findIndex(fn)
    },
    filter: (collection, predicate) => {
      if (!collection)
        return []
      const fn = typeof predicate === 'string' ? item => item[predicate] !== undefined : predicate
      return collection.filter(fn)
    },
    keys: obj => obj ? Object.keys(obj) : [],
    values: obj => obj ? Object.values(obj) : [],
    intersection: (array, other) => array.filter(value => other.includes(value)),
    flatMap: collection => collection ? [].concat(...collection) : []
  }
  const attendeesSource = readFileSync(
    new URL('../../UI/WebServerResources/js/Scheduler/Attendees.service.js', import.meta.url),
    'utf8')
  new Function('angular', '_', attendeesSource)(angular, _)
  const freebusySource = readFileSync(
    new URL('../../UI/WebServerResources/js/Scheduler/sgFreebusy.directive.js', import.meta.url),
    'utf8')
  new Function('angular', '_', freebusySource)(angular, _)
  return { registered }
}

function installDateExtensions() {
  const pad = number => String(number).padStart(2, '0')
  Date.prototype.getDayString = function () {
    return '' + this.getFullYear() + pad(this.getMonth() + 1) + pad(this.getDate())
  }
  Date.prototype.beginOfDay = function () {
    const date = new Date(this.getTime())
    date.setHours(0, 0, 0, 0)
    return date
  }
  Date.prototype.addDays = function (days) {
    this.setDate(this.getDate() + days)
    return this
  }
  Date.prototype.addMinutes = function (minutes) {
    this.setMinutes(this.getMinutes() + minutes)
    return this
  }
  Date.prototype.daysUpTo = function (end) {
    const days = []
    for (let date = new Date(this.getTime()); date.getTime() <= end.getTime(); date.addDays(1))
      days.push(new Date(date.getTime()))
    return days
  }
  Date.prototype.clone = function () {
    return new Date(this.getTime())
  }
}

// Synchronous $q: watchers and freebusy fetches settle within the same digest
function makeQ() {
  const when = value => ({
    then: callback => { callback(value); return when(value) },
    catch: () => when(value)
  })
  return {
    when: when,
    all: () => ({ then: callback => { callback() }, catch: () => {} })
  }
}

function newEditor() {
  const { registered } = loadSources()
  installDateExtensions()
  const $q = makeQ()
  const Preferences = {
    defaults: {
      SOGoDayStartTime: '9:00',
      SOGoDayEndTime: '17:00',
      SOGoLDAPGroupExpansionEnabled: false,
      SOGoLongDateFormat: 'EEEE d MMMM yyyy'
    },
    $mdDateLocaleProvider: { formatDate: date => '' }
  }
  const settings = {
    activeUser: property => ({
      login: 'sogo-tests1',
      folderURL: '/SOGo/so/sogo-tests1/',
      identification: 'Sogo Tests One',
      email: 'sogo-tests1@sogo.local'
    }[property])
  }
  const Resource = function () {
    this.userResource = () => ({ fetch: () => $q.when({}) })
  }
  const annotated = registered.factories.Attendees
  const factory = Array.isArray(annotated) ? annotated[annotated.length - 1] : annotated
  const Attendees = factory(
    $q, () => {}, console, settings, registered.constants.Attendees_ROLES,
    Preferences, {}, {}, () => '', Resource)

  const component = {
    start: new Date(2026, 9, 5, 10, 0, 0),
    end: new Date(2026, 9, 5, 11, 0, 0),
    delta: 60,
    isAllDay: false,
    type: 'event'
  }
  component.$attendees = new Attendees(component)

  // Instantiate the sgFreebusy controller the way Angular binds it, and drive
  // its watcher manually: a refresh happens when onUpdate is invoked
  const ddo = registered.directives.sgFreebusy()
  const watchers = []
  const $scope = { $watch: (watchFn, listener) => watchers.push({ watchFn, listener }) }
  const ctrl = new ddo.controller($scope, {}, $q)
  ctrl.component = component
  let updates = 0
  ctrl.$onInit()
  ctrl.onUpdate = () => { updates++ }

  const digest = () => {
    watchers.forEach(watcher => {
      const value = watcher.watchFn()
      if (value === null || JSON.stringify(value) !== JSON.stringify(watcher.last)) {
        const previous = watcher.last
        watcher.last = JSON.parse(JSON.stringify(value))
        watcher.listener(value, previous)
      }
    })
    return updates
  }
  digest()

  const internalCard = () => ({
    c_uid: 'sogo-tests2',
    c_cn: 'Sogo Tests Two',
    $$email: 'sogo-tests2@sogo.local',
    emails: [{ value: 'sogo-tests2@sogo.local' }],
    $isList: () => false
  })
  const externalCard = () => ({
    c_uid: undefined,
    c_cn: 'John External',
    $$email: 'john@example.net',
    emails: [{ value: 'john@example.net' }],
    $isList: () => false
  })

  const addCard = card => {
    const before = updates
    component.$attendees.add(card, {})
    digest()
    return updates > before
  }

  return {
    component,
    addCard,
    internalCard,
    externalCard,
    refreshCount: () => updates,
    freebusyKeys: () => Object.keys(component.$attendees.$futureFreebusyData).sort(),
    removeAttendee: attendee => {
      const before = updates
      component.$attendees.remove(attendee)
      digest()
      return updates > before
    }
  }
}

describe('freebusy refresh of uid-less attendees (bug 6079)', function() {

  it('refreshes the freebusy view when an external attendee is added after an internal one', function() {
    const editor = newEditor()

    expect(editor.addCard(editor.internalCard()))
      .withContext('adding the internal attendee must refresh the freebusy view')
      .toBe(true)

    expect(editor.addCard(editor.externalCard()))
      .withContext('adding the external attendee after an internal one must refresh the freebusy view (bug 6079)')
      .toBe(true)

    expect(editor.freebusyKeys())
      .withContext('the external attendee must be tracked in the watched freebusy data')
      .toEqual(['john@example.net', 'sogo-tests1', 'sogo-tests2'])
  })

  it('still refreshes the freebusy view when the external attendee comes first', function() {
    const editor = newEditor()

    expect(editor.addCard(editor.externalCard()))
      .withContext('adding the external attendee first must refresh the freebusy view')
      .toBe(true)

    expect(editor.addCard(editor.internalCard()))
      .withContext('adding the internal attendee afterwards must refresh the freebusy view')
      .toBe(true)
  })

  it('drops the external attendee from the watched freebusy data on removal', function() {
    const editor = newEditor()
    editor.addCard(editor.internalCard())
    editor.addCard(editor.externalCard())

    const external = editor.component.attendees.find(attendee => attendee.email === 'john@example.net')
    editor.removeAttendee(external)

    expect(editor.freebusyKeys())
      .withContext('removing the external attendee must drop its watched freebusy entry')
      .toEqual(['sogo-tests1', 'sogo-tests2'])

    expect(editor.addCard(editor.externalCard()))
      .withContext('re-adding the external attendee must refresh the freebusy view again')
      .toBe(true)
  })
})
