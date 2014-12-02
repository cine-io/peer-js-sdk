CineIOPeer = require('../../src/main')

class FakeMediaStream
  constructor: ->
    @ended = false
    @id = @label = "stream-id"

module.exports = ->
  beforeEach ->
    sinon.stub CineIOPeer, '_unsafeGetUserMedia', (streamOptions, callback)->
      callback(null, new FakeMediaStream)
    sinon.stub window.URL, 'createObjectURL', (mediaStream)->
      return "blob:http%3A//#{window.location.host}/identifier"

  afterEach ->
    CineIOPeer._unsafeGetUserMedia.restore()
    window.URL.createObjectURL.restore()
