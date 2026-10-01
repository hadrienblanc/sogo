import config from '../lib/config'
import WebDAV from '../lib/WebDAV'

import {
  DAVNamespace,
  DAVNamespaceShorthandMap,
  davRequest,
  formatProps,
  getDAVAttribute
} from 'tsdav'

const cards = {
  'card-complete.vcf': `BEGIN:VCARD
VERSION:3.0
PRODID:-//Inverse//Card Generator//EN
UID:FILTERTEST-COMPLETE
N:Doe;John
FN:John Doe
EMAIL;TYPE=work:address.email1@domaine.ca
TEL;TYPE=work:+1 514 123-3372
END:VCARD`,
  'card-uppercase.vcf': `BEGIN:VCARD
VERSION:3.0
PRODID:-//Inverse//Card Generator//EN
UID:FILTERTEST-UPPERCASE
N:Noir;Jane
FN:Jane Noir
EMAIL;TYPE=home:ADDRESS.EMAIL2@DOMAINE.CA
END:VCARD`,
  'card-no-email.vcf': `BEGIN:VCARD
VERSION:3.0
PRODID:-//Inverse//Card Generator//EN
UID:FILTERTEST-NOEMAIL
N:Sans;Mail
FN:Mail Sans
TEL;TYPE=work:+1 514 987-6543
END:VCARD`,
  'card-group.vcf': `BEGIN:VCARD
VERSION:3.0
PRODID:-//Inverse//Card Generator//EN
UID:FILTERTEST-GROUP
N:Groupe;Item
FN:Item Groupe
ITEM1.EMAIL:groupe@domaine.ca
END:VCARD`
}

describe('CardDAV addressbook-query filters', function() {
  const webdav = new WebDAV(config.username, config.password)
  const webdav_su = new WebDAV(config.superuser, config.superuser_password)
  const resource = `/SOGo/dav/${config.username}/Contacts/test-carddav-filters/`

  const query = async function(filter) {
    const ns = DAVNamespaceShorthandMap[DAVNamespace.CARDDAV]
    const response = await davRequest({
      url: webdav.serverUrl + resource,
      init: {
        method: 'REPORT',
        namespace: ns,
        headers: { ...webdav.headers, depth: '1' },
        body: {
          'addressbook-query': {
            _attributes: getDAVAttribute([
              DAVNamespace.CARDDAV,
              DAVNamespace.DAV
            ]),
            [`${DAVNamespaceShorthandMap[DAVNamespace.DAV]}:prop`]: formatProps([{ name: 'getetag', namespace: DAVNamespace.DAV }]),
            filter
          }
        },
        elementNameFn: (name) => {
          if (!/^.+:.+/.test(name)) {
            return `${ns}:${name}`
          }
          return name
        }
      }
    })

    return response
      .filter(r => r.status === 207)
      .map(r => r.href.split('/').pop())
      .sort()
  }

  const filterOn = function(propFilters, test) {
    return {
      _attributes: test ? { test: test } : {},
      'prop-filter': propFilters
    }
  }

  const textMatch = function(value, attributes) {
    return {
      'text-match': {
        _attributes: Object.assign({ collation: 'i;unicode-casemap' }, attributes),
        _text: value
      }
    }
  }

  beforeAll(async function() {
    jasmine.DEFAULT_TIMEOUT_INTERVAL = config.timeout || 20000
    await webdav.deleteObject(resource)
    await webdav.makeCollection(resource)
    for (let key of Object.keys(cards)) {
      const response = await webdav.createVCard(resource, key, cards[key])
      expect(response.status).toBe(201)
    }
  })

  afterAll(async function() {
    await webdav_su.deleteObject(resource)
  })

  it('#5955 equals matches the whole value, case-insensitively', async function() {
    let results

    results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, ...textMatch('address.email1@domaine.ca', { 'match-type': 'equals' }) }
    ]))
    expect(results).toEqual(['card-complete.vcf'])

    results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, ...textMatch('ADDRESS.EMAIL1@DOMAINE.CA', { 'match-type': 'equals' }) }
    ]))
    expect(results).toEqual(['card-complete.vcf'])

    results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, ...textMatch('email1', { 'match-type': 'equals' }) }
    ]))
    expect(results).toEqual([])
  })

  it('starts-with, ends-with and contains anchor correctly', async function() {
    let results

    results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, ...textMatch('address.email1', { 'match-type': 'starts-with' }) }
    ]))
    expect(results).toEqual(['card-complete.vcf'])

    results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, ...textMatch('email1', { 'match-type': 'starts-with' }) }
    ]))
    expect(results).toEqual([])

    results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, ...textMatch('email2@domaine.ca', { 'match-type': 'ends-with' }) }
    ]))
    expect(results).toEqual(['card-uppercase.vcf'])

    results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, ...textMatch('domaine.ca', { 'match-type': 'ends-with' }) }
    ]))
    expect(results).toEqual([])

    results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, ...textMatch('email', { 'match-type': 'contains' }) }
    ]))
    expect(results).toEqual(['card-complete.vcf', 'card-group.vcf', 'card-uppercase.vcf'])
  })

  it('#5956 negate-condition returns the cards that do not match', async function() {
    const results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, ...textMatch('email1', { 'match-type': 'contains', 'negate-condition': 'yes' }) }
    ]))
    expect(results).toEqual(['card-group.vcf', 'card-no-email.vcf', 'card-uppercase.vcf'])
  })

  it('#5954 a prop-filter without text-match selects cards holding the property', async function() {
    const results = await query(filterOn([
      { _attributes: { name: 'EMAIL' } }
    ]))
    expect(results).toEqual(['card-complete.vcf', 'card-group.vcf', 'card-uppercase.vcf'])
  })

  it('#5954 is-not-defined selects cards lacking the property', async function() {
    let results

    results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, 'is-not-defined': {} }
    ]))
    expect(results).toEqual(['card-no-email.vcf'])

    results = await query(filterOn([
      { _attributes: { name: 'TEL' }, 'is-not-defined': {} }
    ]))
    expect(results).toEqual(['card-group.vcf', 'card-uppercase.vcf'])
  })

  it('#5955 a group-prefixed property name filters on the base property', async function() {
    const results = await query(filterOn([
      { _attributes: { name: 'ITEM1.EMAIL' }, ...textMatch('groupe', { 'match-type': 'contains' }) }
    ]))
    expect(results).toEqual(['card-group.vcf'])
  })

  it('FN text-matches cover the whole name, not only the surname', async function() {
    let results

    results = await query(filterOn([
      { _attributes: { name: 'FN' }, ...textMatch('jane', { 'match-type': 'contains' }) }
    ]))
    expect(results).toEqual(['card-no-email.vcf', 'card-uppercase.vcf'])

    results = await query(filterOn([
      { _attributes: { name: 'N' }, ...textMatch('john', { 'match-type': 'contains' }) }
    ]))
    expect(results).toEqual(['card-complete.vcf'])
  })

  it('anyof and allof combine prop-filters', async function() {
    let results

    results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, ...textMatch('email1', { 'match-type': 'contains' }) },
      { _attributes: { name: 'FN' }, ...textMatch('sans', { 'match-type': 'contains' }) }
    ], 'anyof'))
    expect(results).toEqual(['card-complete.vcf', 'card-no-email.vcf'])

    results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, ...textMatch('email1', { 'match-type': 'contains' }) },
      { _attributes: { name: 'FN' }, ...textMatch('sans', { 'match-type': 'contains' }) }
    ], 'allof'))
    expect(results).toEqual([])

    results = await query(filterOn([
      { _attributes: { name: 'EMAIL' }, ...textMatch('email1', { 'match-type': 'contains' }) },
      { _attributes: { name: 'FN' }, ...textMatch('john', { 'match-type': 'contains' }) }
    ], 'allof'))
    expect(results).toEqual(['card-complete.vcf'])
  })

  it('multiple text-matches combine with the prop-filter test attribute', async function() {
    const results = await query(filterOn([
      {
        _attributes: { name: 'EMAIL', test: 'anyof' },
        ...{
          'text-match': [
            { _attributes: { collation: 'i;unicode-casemap', 'match-type': 'contains' }, _text: 'email1' },
            { _attributes: { collation: 'i;unicode-casemap', 'match-type': 'contains' }, _text: 'groupe' }
          ]
        }
      }
    ]))
    expect(results).toEqual(['card-complete.vcf', 'card-group.vcf'])
  })
})
