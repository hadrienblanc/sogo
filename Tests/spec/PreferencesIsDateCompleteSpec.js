import { readFileSync } from 'fs'

global.angular = global.angular || { isNumber: v => typeof v === 'number' }
global.Element = global.Element || class Element {}
await import(new URL('../../UI/WebServerResources/js/Common/utils.js', import.meta.url).pathname)

//
// Unit test of the md-datepicker locale adapter installed by the
// Preferences service (bugs.sogo.nu #6182). Short date formats that
// end with a dot (Hungarian %Y.%b.%d., Montenegrin %e.%m.%y.) must be
// reported as complete dates, otherwise the date picker marks its model
// invalid and the save button of the whole preferences form stays
// disabled. The service is loaded from its AngularJS source with
// stubbed dependencies; no SOGo server is required.

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

function loadDateLocale(defaults) {
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
    path.join(__dirname, '../../UI/WebServerResources/js/Preferences/Preferences.service.js'),
    'utf8')
  new Function('angular', '_', 'l', 'window', source)(angular, global._, key => key, {})

  const factoryArray = registeredFactories['Preferences']
  const factory = factoryArray[factoryArray.length - 1]
  const dateLocale = {}
  const document = [{
    getElementById: id => id === 'UserDefaults' ? { textContent: JSON.stringify(defaults) } : null
  }]
  const Settings = {
    activeUser: () => 'sogo-tests1',
    resourcesURL: () => '/SOGo.woa/WebServerResources'
  }
  class Resource {}
  factory({}, document, {}, { when: () => ({}) }, () => {},
          { error: () => {}, warn: () => {}, debug: () => {} }, { get: () => null },
          dateLocale, {}, {}, Settings, () => '', Resource, class {})

  return dateLocale
}

describe('Preferences date locale (bug 6182)', function() {

  const hungarianShortMonths = ['jan', 'febr', 'márc', 'ápr', 'máj', 'jún',
                                'júl', 'aug', 'szept', 'okt', 'nov', 'dec']
  const localeTables = {
    months: hungarianShortMonths,
    shortMonths: hungarianShortMonths,
    days: [],
    shortDays: []
  }
  const hungarian = loadDateLocale({
    SOGoShortDateFormat: '%Y.%b.%d.',
    SOGoFirstDayOfWeek: 1,
    locale: localeTables
  })
  const montenegrin = loadDateLocale({
    SOGoShortDateFormat: '%e.%m.%y.',
    SOGoFirstDayOfWeek: 1,
    locale: localeTables
  })

  it('formats Hungarian dates with a trailing dot and reports them complete', function() {
    const dateString = hungarian.formatDate(new Date(2026, 2, 23))
    expect(dateString)
      .withContext('formatted %Y.%b.%d. date')
      .toBe('2026.márc.23.')
    expect(hungarian.isDateComplete(dateString))
      .withContext('isDateComplete on the formatted date')
      .toBe(true)
  })

  it('reports Montenegrin dates with a trailing dot as complete (%e.%m.%y.)', function() {
    const dateString = montenegrin.formatDate(new Date(2026, 2, 23))
    expect(dateString)
      .withContext('formatted %e.%m.%y. date')
      .toBe('23.03.26.')
    expect(montenegrin.isDateComplete(dateString))
      .withContext('isDateComplete on the formatted date')
      .toBe(true)
  })

  it('parses back a date formatted with a trailing dot', function() {
    const parsed = hungarian.parseDate('2026.márc.23.')
    expect(parsed.getFullYear()).toBe(2026)
    expect(parsed.getMonth()).toBe(2)
    expect(parsed.getDate()).toBe(23)
  })

  it('still reports dot-free dates as complete', function() {
    expect(hungarian.isDateComplete('23-Mar-26')).toBe(true)
    expect(hungarian.isDateComplete('3/14/16')).toBe(true)
    expect(hungarian.isDateComplete('23.03.26')).toBe(true)
  })

  it('still reports partially typed dates as incomplete', function() {
    expect(hungarian.isDateComplete('23.03')).toBe(false)
    expect(hungarian.isDateComplete('2026.márc')).toBe(false)
    expect(hungarian.isDateComplete('23.03.26..')).toBe(false)
  })
})
