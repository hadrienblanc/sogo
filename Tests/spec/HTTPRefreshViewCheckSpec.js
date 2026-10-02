import config from '../lib/config.js'
import Preferences from '../lib/Preferences.js'

const prefs = new Preferences(config.username, config.password)

describe('refresh view check defaults (bug 6142)', function() {

  let original

  beforeAll(async function() {
    jasmine.DEFAULT_TIMEOUT_INTERVAL = config.timeout || 10000
    original = await prefs.get('SOGoRefreshViewCheck')
  })

  afterAll(async function() {
    if (original !== null)
      await prefs.set('SOGoRefreshViewCheck', original)
  })

  it('delivers SOGoRefreshViewCheck as a string token (bug 6142)', async function() {
    const defaults = await prefs.getDefaults()
    expect(defaults.SOGoRefreshViewCheck)
      .withContext(`SOGoRefreshViewCheck must always be part of the JSON defaults`)
      .toBeDefined()
    expect(typeof defaults.SOGoRefreshViewCheck)
      .withContext(`SOGoRefreshViewCheck must be delivered as a string, as consumed by String.prototype.timeInterval() in the web client`)
      .toEqual('string')
  })

  it('round-trips a valid token as a string (bug 6142)', async function() {
    await prefs.set('SOGoRefreshViewCheck', 'every_minute')
    const defaults = await prefs.getDefaults()
    expect(defaults.SOGoRefreshViewCheck)
      .withContext(`a valid token must round-trip unchanged`)
      .toEqual('every_minute')
    expect(typeof defaults.SOGoRefreshViewCheck)
      .withContext(`a valid token must round-trip as a string`)
      .toEqual('string')
  })
})
