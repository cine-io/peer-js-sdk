CineIOPeer = require('../../src/main')

class FakeMediaStream
  constructor: ->
    @ended = false
    @id = @label = "stream-id"

module.exports = (success=true)->
  beforeEach ->
    sinon.stub CineIOPeer, '_unsafeGetUserMedia', (streamOptions, callback)->
      if success
        callback(null, new FakeMediaStream)
      else
        callback('could not fetch media')
    sinon.stub window.URL, 'createObjectURL', (mediaStream)->
      return "blob:http%3A//#{window.location.host}/identifier"

  afterEach ->
    CineIOPeer._unsafeGetUserMedia.restore()
    window.URL.createObjectURL.restore()
