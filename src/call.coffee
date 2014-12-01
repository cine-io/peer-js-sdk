module.exports = class CallObject
  constructor: (@_data)->

  answer: =>
    CineIOPeer.join(@_data.room)

  reject: ->
    # TODO: send a reject response back

CineIOPeer = require('./main')
