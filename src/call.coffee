noop = ->
module.exports = class CallObject
  constructor: (@_data)->

  answer: (callback=noop)=>
    CineIOPeer.join(@_data.room, callback)

  reject: (callback=noop)->
    CineIOPeer._signalConnection.write action: 'call-reject', room: @_data.room, publicKey: CineIOPeer.config.publicKey

  hangup: (callback=noop)->
    CineIOPeer.leave @_data.room, callback

CineIOPeer = require('./main')
