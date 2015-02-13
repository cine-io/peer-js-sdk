PeerConnection = require('rtcpeerconnection')

iceServers = null

exports.create = ->
  return null unless iceServers
  exports._actuallyCreatePeerConnection(iceServers: iceServers)

exports._actuallyCreatePeerConnection = (options)->
  new PeerConnection()

exports._reset = ->
  iceServers = null

Main = require('./main')
Main.on 'gotIceServers', (data)->
  iceServers = data
