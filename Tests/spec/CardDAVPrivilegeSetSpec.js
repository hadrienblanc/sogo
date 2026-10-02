import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'

beforeAll(function () {
  jasmine.DEFAULT_TIMEOUT_INTERVAL = config.timeout || 10000;
});

describe('current-user-privilege-set on address books (bug 6179)', function() {
  const webdav = new WebDAV(config.username, config.password)
  const webdav_su = new WebDAV(config.superuser, config.superuser_password)
  const webdav_subscriber = new WebDAV(config.subscriber_username, config.subscriber_password)
  const utility = new TestUtility(webdav)

  const resource = `/SOGo/dav/${config.username}/Contacts/test-6179-acl/`

  const _privileges = async function(client) {
    const results = await client.currentUserPrivilegeSet(resource)
    expect(results.length).toBe(1)
    expect(results[0].status).toBe(207)
    return results[0].props.currentUserPrivilegeSet.privilege.map(o => {
      return Object.keys(o)[0]
    })
  }

  beforeEach(async function() {
    await webdav.deleteObject(resource)
    await webdav.makeCollection(resource)
  })

  afterEach(async function() {
    await webdav_su.deleteObject(resource)
  })

  it('read-only subscriber gets the DAV read privilege', async function() {
    const results = await utility.setupAddressBookRights(resource, config.subscriber_username, { v: true })
    expect(results.length).toBe(1)
    expect(results[0].status).toBe(204)

    const privileges = await _privileges(webdav_subscriber)
    expect(privileges)
      .withContext('privileges reported to a read-only subscriber')
      .toContain('read')
    expect(privileges)
      .withContext('read-current-user-privilege-set reported to a read-only subscriber')
      .toContain('readCurrentUserPrivilegeSet')
    expect(privileges)
      .withContext('a read-only subscriber must not obtain write privileges')
      .not.toContain('write')
  })

  it('owner gets the DAV read privilege', async function() {
    const privileges = await _privileges(webdav)
    expect(privileges)
      .withContext('privileges reported to the owner')
      .toContain('read')
    expect(privileges)
      .withContext('write privileges reported to the owner')
      .toContain('write')
  })
})
