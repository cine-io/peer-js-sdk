PeerConnection = require('rtcpeerconnection')
uuid = require('./vendor/uuid')

Primus = require('./vendor/primus')
nearestServer = require('./nearest_server')

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
    console.log("Writing", data)
    @primus.write(arguments...)

  startBroadcast: (streamType, streamId, streamKey, mediaStream, callback)->
    console.log("ensuring ready")
    @_ensureReady =>
      console.log("ready")
      peerConnection = @_initializeNewPeerConnection(iceServers: @broadcastBridge.iceServers)
      @peerConnections[streamType] = peerConnection
      peerConnection.addStream(mediaStream)
      console.log("waiting for ice")

      peerConnection.on 'close', (event)=>
        @_onCloseOfPeerConnection(peerConnection)
        delete @peerConnections[streamType]

      @_createOffer peerConnection, (err, offer)=>
        console.log("MADE OFFER", err, offer)
        return callback(err) if err
        peerConnection.on 'endOfCandidates', (candidate)=>
          console.log("got all candidates")
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
    console.log("Connection closed")

  _signalHandler: (data)=>
    console.log("got data", data)
    switch data.action
      # BASE
      when 'error'
        CineIOPeer.trigger('error', data)

      when 'ack'
        console.log("ack")
      # END BASE

      # RTC
      when 'rtc-answer'
        console.log('got answer', data)
        pc = @peerConnections[data.streamType]
        pc.handleAnswer(data.answer)
      # END RTC
      # else
      #   console.log("UNKNOWN DATA", data)

  _createOffer: (peerConnection, callback)->
    response = (err, offer)->
      if err || !offer
        console.log("FATAL ERROR in offer", err, offer)
        return CineIOPeer.trigger("error", kind: 'offer', fatal: true, err: err)
      console.log('offering', err, offer)
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

  _initializeNewPeerConnection: (options)->
    new PeerConnection(options)

module.exports = class BroadcastBridge
  constructor: (@CineIOPeer)->
    @CineIOPeer.on 'gotIceServers', (data)=>
      console.log("GOT ICE")
      @iceReady = true
      @iceServers = data
    @connection = new Connection(this)

  startBroadcast: (streamType, mediaStream, streamId, streamKey, callback=noop)->
    @_ensureConnection =>
      @connection.startBroadcast(streamType, streamId, streamKey, mediaStream, callback)

  stopBroadcast: (streamType, callback)->
    return callback() unless @connection.connected
    @connection.stopBroadcast(streamType, callback)

  _ensureConnection: (callback)->
    if @connection.connected
      return setTimeout ->
        callback()
    nearestServer (err, ns)=>
      console.log("HERE I AM", err, ns)
      return callback(err) if err
      @connection.connectToCineBroadcastBridge(ns.rtcPublish)
      callback()
