import config from '../lib/config'
import { fetch } from 'cross-fetch'
import Preferences from '../lib/Preferences'

const ownerPrefs = new Preferences(config.username, config.password)
const viewerPrefs = new Preferences(config.subscriber_username, config.subscriber_password)

const _fetchFreeBusy = async function (prefs, day) {
  const response = await fetch(`${prefs.serverUrl}/SOGo/so/${config.username}/freebusy.ifb/ajaxRead?sday=${day}&eday=${day}`, {
    headers: { Cookie: await prefs.getAuthCookie() }
  })
  expect(response.status)
    .withContext('ajaxRead on the freebusy object must succeed')
    .toEqual(200)
  return response.json()
}

describe('freebusy "busy outside working hours" (bug 6247)', function() {

  let day, weekday, originalOwnerTimeZone, originalViewerTimeZone
  let originalDayStart, originalDayEnd, originalBusyOffHours

  const _busyHours = function (dayData) {
    const hours = []
    for (let hour = 0; hour < 24; hour++) {
      const quarters = dayData[String(hour)]
      if (quarters && Object.values(quarters).some(count => count > 0))
        hours.push(hour)
    }
    return hours.sort((a, b) => a - b)
  }

  beforeAll(async function() {
    jasmine.DEFAULT_TIMEOUT_INTERVAL = config.timeout || 10000

    originalOwnerTimeZone = await ownerPrefs.get('SOGoTimeZone')
    originalViewerTimeZone = await viewerPrefs.get('SOGoTimeZone')
    originalDayStart = await ownerPrefs.get('SOGoDayStartTime')
    originalDayEnd = await ownerPrefs.get('SOGoDayEndTime')
    originalBusyOffHours = await ownerPrefs.get('SOGoBusyOffHours')

    const now = new Date()
    const lisbonFormatter = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Lisbon', year: 'numeric', month: '2-digit', day: '2-digit' })
    day = lisbonFormatter.format(now).split('-').join('')
    weekday = new Intl.DateTimeFormat('en-US', { timeZone: 'Europe/Lisbon', weekday: 'short' }).format(now)

    await ownerPrefs.setOrCreate('SOGoTimeZone', 'Europe/Lisbon')
    await ownerPrefs.setOrCreate('SOGoDayStartTime', '10:00')
    await ownerPrefs.setOrCreate('SOGoDayEndTime', '18:00')
    await ownerPrefs.setOrCreate('SOGoBusyOffHours', true)
    await ownerPrefs.save()
    await viewerPrefs.setOrCreate('SOGoTimeZone', 'Europe/Warsaw')
    await viewerPrefs.save()
  })

  afterAll(async function() {
    await ownerPrefs.setOrCreate('SOGoTimeZone', originalOwnerTimeZone)
    await ownerPrefs.setOrCreate('SOGoDayStartTime', originalDayStart)
    await ownerPrefs.setOrCreate('SOGoDayEndTime', originalDayEnd)
    await ownerPrefs.setOrCreate('SOGoBusyOffHours', originalBusyOffHours === null ? false : originalBusyOffHours)
    await ownerPrefs.save()
    await viewerPrefs.setOrCreate('SOGoTimeZone', originalViewerTimeZone)
    await viewerPrefs.save()
  })

  it('shifts off-hours busy blocks to the viewer timezone (bug 6247)', async function() {
    const data = await _fetchFreeBusy(viewerPrefs, day)

    expect(data[day])
      .withContext(`the viewer day ${day} must carry freebusy data`)
      .toBeDefined()

    const isWeekend = (weekday === 'Sat' || weekday === 'Sun')

    const expectedHours = isWeekend
      ? Array.from({ length: 24 }, (v, i) => i)
      : [...Array(11).keys()].concat([19, 20, 21, 22, 23])

    expect(_busyHours(data[day]))
      .withContext(`busy hours on ${day} (${weekday}, owner working hours 10:00-18:00 Europe/Lisbon seen from Europe/Warsaw)`)
      .toEqual(expectedHours)
  })
})
