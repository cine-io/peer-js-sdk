uuid = require('./vendor/uuid')
PeerConnectionFactory = require('./peer_connection_factory')
Primus = require('./vendor/primus')
nearestServer = require('./nearest_server')
debug = require('./debug')('cine:peer:broadcast_bridge')

noop = ->

connectToCineBroadcastBridge = (broadcastUrl)->
  Primus.connect(broadcastUrl)

class Connection
  constructor: (@broadcastBridge, ns)->
    @myUUID = uuid()
    @peerConnections = {}
    @calls = {}
    @connected = false

  connectToCineBroadcastBridge: (ns)->
    @primus = connectToCineBroadcastBridge(ns)
    @primus.on 'open', @_onConnectionOpen
    @primus.on 'data', @_signalHandler
    @primus.on 'end', @_connectionEnded
    @connected = true

  write: (data)=>
    data.client = "cineio-peer-js version-#{CineIOPeer.version}"
    data.publicKey = CineIOPeer.config.publicKey
    data.uuid = @myUUID
    debug("Writing", data)
    @primus.write(arguments...)

  startBroadcast: (streamType, streamId, streamKey, mediaStream, callback)->
    debug("ensuring ready")
    @_ensureReady =>
      debug("ready")
      peerConnection = PeerConnectionFactory.create()
      @peerConnections[streamType] = peerConnection
      peerConnection.addStream(mediaStream)
      debug("waiting for ice")

      peerConnection.on 'close', (event)=>
        @_onCloseOfPeerConnection(peerConnection)
        delete @peerConnections[streamType]

      @_createOffer peerConnection, (err, offer)=>
        debug("MADE OFFER", err, offer)
        return callback(err) if err
        peerConnection.on 'endOfCandidates', (candidate)=>
          debug("got all candidates")
          # you have to do the offer first
          # but if you wait till the end of candidates
          # then your offer actually changes
          # and includes all of the candidates
          # so you can send it in a single bundle
          data =
            streamType: streamType
            action: 'broadcast-start'
            offer: peerConnection.pc.localDescription
            streamId: streamId
            streamKey: streamKey
          @write data
          callback()

  stopBroadcast: (streamType, callback)->
    @peerConnections[streamType].close() if @peerConnections[streamType]
    data =
      streamType: streamType
      action: 'broadcast-stop'
    @write data
    callback()

  _onConnectionOpen: =>
    @write action: 'auth'

  _connectionEnded: ->
    debug("Connection closed")

  _signalHandler: (data)=>
    debug("got data", data)
    switch data.action
      # BASE
      when 'error'
        CineIOPeer.trigger('error', data)

      when 'ack'
        debug("ack")
      # END BASE

      # RTC
      when 'rtc-answer'
        debug('got answer', data)
        pc = @peerConnections[data.streamType]
        pc.handleAnswer(data.answer)
      # END RTC
      # else
      #   debug("UNKNOWN DATA", data)

  _createOffer: (peerConnection, callback)->
    response = (err, offer)->
      if err || !offer
        debug("FATAL ERROR in offer", err, offer)
        return CineIOPeer.trigger("error", kind: 'offer', fatal: true, err: err)
      debug('offering', err, offer)
      callback(err, offer)
    # av = CineIOPeer.localStreams().length == 0
    constraints =
      mandatory:
        OfferToReceiveAudio: true
        OfferToReceiveVideo: true
    # if peerConnection.mainDataChannel
    #   constraints.optional = [{RtpDataChannels: true}]
    peerConnection.offer constraints, response

  _onCloseOfPeerConnection: (peerConnection)->

  _ensureReady: (callback)=>
    @_ensureIce callback

  _ensureIce: (callback)=>
    return setTimeout callback if @broadcastBridge.iceReady
    CineIOPeer.once 'gotIceServers', callback


module.exports = class BroadcastBridge
  constructor: (@CineIOPeer)->
    @CineIOPeer.on 'gotIceServers', (data)=>
      @iceReady = true
    @connection = new Connection(this)

  startBroadcast: (streamType, mediaStream, streamId, streamKey, callback=noop)->
    @_ensureConnection =>
      @connection.startBroadcast(streamType, streamId, streamKey, mediaStream, callback)

  stopBroadcast: (streamType, callback)->
    return callback() unless @connection.connected
    @connection.stopBroadcast(streamType, callback)

  _ensureConnection: (callback=noop)->
    if @connection.connected
      return setTimeout ->
        callback()
    nearestServer (err, ns)=>
      debug("HERE I AM", err, ns)
      return callback(err) if err
      @connection.connectToCineBroadcastBridge(ns.rtcPublish)
      callback()
