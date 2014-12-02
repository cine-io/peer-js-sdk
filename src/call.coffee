module.exports = class CallObject
  constructor: (@_data)->

  answer: =>
    CineIOPeer.join(@_data.room)

  reject: ->
    CineIOPeer._signalConnection.write action: 'reject', room: @_data.room, apikey: CineIOPeer.config.apiKey

CineIOPeer = require('./main')
