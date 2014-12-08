noop = ->
module.exports = class CallObject
  constructor: (@_data)->

  answer: (callback=noop)=>
    CineIOPeer.join(@_data.room, callback)

  reject: ->
    CineIOPeer._signalConnection.write action: 'call-reject', room: @_data.room, publicKey: CineIOPeer.config.publicKey

CineIOPeer = require('./main')
