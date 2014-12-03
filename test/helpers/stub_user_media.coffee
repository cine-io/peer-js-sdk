CineIOPeer = require('../../src/main')
FakeMediaStream = require('./fake_media_stream')
stubCreateObjectUrl = require("./stub_create_object_url")

module.exports = (success=true)->
  stubCreateObjectUrl()

  beforeEach ->
    sinon.stub CineIOPeer, '_unsafeGetUserMedia', (streamOptions, callback)->
      if success
        callback(null, new FakeMediaStream)
      else
        callback('could not fetch media')

  afterEach ->
    CineIOPeer._unsafeGetUserMedia.restore()
