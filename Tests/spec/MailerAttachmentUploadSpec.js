import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'

describe('File attachment upload (bug 6114)', function() {
  let decorators, BlobImpl, nativeBlob

  class Blob {
    constructor(parts, options) {
      this.parts = parts
      this.type = (options && options.type) || ''
    }
  }

  beforeAll(function() {
    nativeBlob = global.Blob
    global.Blob = Blob
    BlobImpl = Blob
    decorators = {}

    const moduleChain = {
      decorator: function(name, decorated) {
        decorators[name] = decorated
        return moduleChain
      }
    }
    global.angular = {
      module: function() { return moduleChain },
      forEach: function() {}
    }

    const source = readFileSync(fileURLToPath(new URL('../../UI/WebServerResources/js/Common/angular-file-upload.trump.js', import.meta.url)), 'utf8')
    new Function('angular', source)(global.angular)
    delete global.angular
  })

  afterAll(function() {
    global.Blob = nativeBlob
  })

  const _decoratedUploader = function(xsrfToken) {
    const FileUploader = function() {}
    const cookies = {
      get: function(name) {
        return name == 'XSRF-TOKEN' ? xsrfToken : undefined
      }
    }
    decorators.FileUploader(FileUploader, cookies)
    return FileUploader
  }

  it('uploads mail attachments as opaque octet-stream parts carrying the real type', function() {
    const FileUploader = _decoratedUploader('token-1')
    const file = new BlobImpl(['payload'], { type: 'text/plain' })
    const item = { alias: 'attachments', _file: file, formData: [], headers: {} }

    FileUploader.prototype.onBeforeUploadItem(item)

    expect(item._file.type)
      .withContext('the uploaded part must not be decoded as text by the server')
      .toBe('application/octet-stream')
    expect(item._file.parts)
      .withContext('the original file must be wrapped, not replaced')
      .toEqual([file])
    expect(item.formData)
      .withContext('the browser-provided type must travel in the attachmentMimeType field')
      .toEqual([{ attachmentMimeType: 'text/plain' }])
    expect(item.headers['X-XSRF-TOKEN'])
      .withContext('the XSRF header must still be set')
      .toBe('token-1')
  })

  it('defaults the declared type when the browser provides none', function() {
    const FileUploader = _decoratedUploader(undefined)
    const item = {
      alias: 'attachments',
      _file: new BlobImpl(['payload'], { type: '' }),
      formData: []
    }

    FileUploader.prototype.onBeforeUploadItem(item)

    expect(item.formData).toEqual([{ attachmentMimeType: 'application/octet-stream' }])
    expect(item._file.type).toBe('application/octet-stream')
  })

  it('leaves non-mailer uploads untouched', function() {
    const FileUploader = _decoratedUploader('token-2')
    const file = new BlobImpl(['card'], { type: 'text/vcard' })
    const item = { alias: 'file', _file: file, formData: [], headers: {} }

    FileUploader.prototype.onBeforeUploadItem(item)

    expect(item._file).toBe(file)
    expect(item._file.type).toBe('text/vcard')
    expect(item.formData).toEqual([])
  })
})
