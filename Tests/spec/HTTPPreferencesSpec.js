import config from '../lib/config.js'
import Preferences from '../lib/Preferences.js'

const prefs = new Preferences(config.username, config.password)

beforeAll(function () {
  jasmine.DEFAULT_TIMEOUT_INTERVAL = config.timeout || 10000;
});

describe('preferences', function() {

  // preferencesTest

  const _setTextPref = async function(prefText) {
    await prefs.set('autoReplyText', prefText)
    const prefData = await prefs.get('Vacation')

    expect(prefData.autoReplyText)
      .withContext(`Set a text preference to a known value`)
      .toEqual(prefText)
  }

  beforeAll(async function() {
    // because if not set in vacation will not be found later
    // we must make sure they are there at the start
    await prefs.setOrCreate('autoReplyText', '', ['defaults', 'Vacation'])
    await prefs.setOrCreate('PreventInvitations', 0, ['settings', 'Calendar'])
    await prefs.setOrCreate('PreventInvitationsWhitelist', {}, ['settings', 'Calendar'])
  })

  it('Set/get a text preference - normal characters', async function() {
    await _setTextPref('defaultText')
  })

  it('Set/get a text preference - weird characters - used to crash on 1.3.12', async function() {
    const prefText = `weird data   \ ' \"; ^`
    await _setTextPref(prefText)
  })

  it('Set/get the PreventInvitation pref', async function() {
    await prefs.set('PreventInvitations', 0)
    const notset = await prefs.get('Calendar', false)
    expect(notset.PreventInvitations)
      .withContext(`Set/get Settings/Calendar/PreventInvitations (0)`)
      .toEqual(0)
    await prefs.set('PreventInvitations', 1)
    const isset = await prefs.get('Calendar', false)
    expect(isset.PreventInvitations)
      .withContext(`Set/get Settings/Calendar/PreventInvitations (1)`)
      .toEqual(1)
  })

  it('Set/get the PreventInvitations Whitelist', async function() {
    await prefs.set('PreventInvitationsWhitelist', config.white_listed_attendee)
    const whitelist = await prefs.get('Calendar', false)
    expect(whitelist.PreventInvitationsWhitelist)
      .withContext(`Set/get Settings/Calendar/PreventInvitationsWhitelist`)
      .toEqual(config.white_listed_attendee)
  })

  it('#6243 saving defaults without mail identities keeps the account usable', async function() {
    const identity = { fullName: 'Identity Probe', email: `probe-${Date.now()}@example.org`, isDefault: 1 }

    try {
      await prefs.loadPreferences()
      const accounts = await prefs.get('AuxiliaryMailAccounts')
      const previousIdentities = (accounts[0] && accounts[0].identities) || []
      const previousOutgoing = await prefs.get('SOGoMailAddOutgoingAddresses')
      const previousSelected = await prefs.get('SOGoSelectedAddressBook')

      if (accounts[0])
        accounts[0].identities = [identity]
      await prefs.setOrCreate('SOGoMailAddOutgoingAddresses', 1)
      await prefs.setOrCreate('SOGoSelectedAddressBook', 'collected')
      let response = await prefs.save()
      expect(response.status)
        .withContext(`HTTP status of the save holding identities`)
        .toEqual(200)

      await prefs.loadPreferences()
      delete prefs.preferences.defaults.SOGoMailIdentities
      response = await prefs.save()
      expect(response.status)
        .withContext(`HTTP status of Preferences/save without identities`)
        .toEqual(200)

      response = await prefs.save()
      expect(response.status)
        .withContext(`HTTP status of a subsequent save`)
        .toEqual(200)

      await prefs.loadPreferences()
      const accountsRestore = await prefs.get('AuxiliaryMailAccounts')
      if (accountsRestore[0])
        accountsRestore[0].identities = previousIdentities
      await prefs.setOrCreate('SOGoMailAddOutgoingAddresses', previousOutgoing)
      await prefs.setOrCreate('SOGoSelectedAddressBook', previousSelected)
      await prefs.save()
    }
    catch (e) {
      await prefs.loadPreferences().catch(() => {})
      await prefs.save().catch(() => {})
      throw e
    }
  })
})
