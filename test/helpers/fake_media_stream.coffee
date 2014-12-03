module.exports = class FakeMediaStream
  constructor: ->
    @ended = false
    @id = @label = "stream-id"
