uuid = require('./vendor/uuid')
PeerConnectionFactory = require('./peer_connection_factory')
debug = require('./debug')('cine:peer:signaling_connection')

Primus = require('./vendor/primus')
Config = require('./config')

noop = ->
connectToCineSignaling = ->
  Primus.connect(Config.signalingServer)

PENDING = 1

sendToDataChannel = (dataChannel, data)->
  return dataChannel.send(JSON.stringify(data)) if dataChannel.readyState == 'open'
  dataChannel.dataToSend.push data

setSparkIdOnPeerConnection = (peerConnection, otherClientSparkId)->
  peerConnection.otherClientSparkId = otherClientSparkId

class Connection
  constructor: (@options)->
    @myUUID = uuid()
    @iceServers = null
    @fetchedIce = false
    @peerConnections = {}
    @calls = {}
    @primus = connectToCineSignaling()
    @primus.on 'open', @_onConnectionOpen
    @primus.on 'data', @_signalHandler
    @primus.on 'end', @_connectionEnded

  write: (data)=>
    data.client = "cineio-peer-js version-#{CineIOPeer.version}"
    data.publicKey = CineIOPeer.config.publicKey
    data.uuid = @myUUID
    data.identity = CineIOPeer.config.identity.identity if CineIOPeer.config.identity
    data.support =
      trickleIce: true
    debug("Writing", data)
    @primus.write(arguments...)

  addLocalStream: (stream, options={})=>
    for otherClientUUID, peerConnection of @peerConnections
      debug "adding local stream #{stream.id} to #{otherClientUUID}"
      peerConnection.addStream(stream)
      # need to reoffer every time there's a new stream
      # http://stackoverflow.com/questions/16015022/webrtc-how-to-add-stream-after-offer-and-answer
      @_sendOffer(peerConnection) unless options.silent

  removeLocalStream: (stream, options={})=>
    for otherClientUUID, peerConnection of @peerConnections
      debug "removing local stream #{stream.id} from #{otherClientUUID}"
      peerConnection.removeStream(stream)
      @_sendOffer(peerConnection) unless options.silent

  sendDataToAllPeers: (data)->
    for otherClientUUID, peerConnection of @peerConnections
      debug "sending data #{data} to #{otherClientUUID}"
      @_sendDataToPeer(peerConnection, data)

  _sendDataToPeer: (peerConnection, data)->
    unless peerConnection.mainDataChannel
      peerConnection.mainDataChannel = @_newDataChannel(peerConnection)
      @_sendOffer(peerConnection)

    sendToDataChannel peerConnection.mainDataChannel, action: 'userData', data: data

  _newDataChannel: (peerConnection)->
    dataChannel = peerConnection.createDataChannel 'CINE',
      ordered: false # do not guarantee order
      maxRetransmitTime: 3000 # in milliseconds
    @_prepareDataChannel(peerConnection, dataChannel)
    dataChannel

  _prepareDataChannel: (peerConnection, dataChannel)->
    dataChannel.dataToSend = []
    dataChannel.onopen = (event)->
      debug("ON OPEN", event)
      if dataChannel.readyState == "open"
        for data in dataChannel.dataToSend
          debug("Actually sending data", data)
          sendToDataChannel(dataChannel, data)
        delete dataChannel.dataToSend

    dataChannel.onmessage = (event)->
      if event && event.data
        data = JSON.parse(event.data)
        CineIOPeer.trigger('peer-data', data.data) if data.action == 'userData'

    dataChannel

  _onConnectionOpen: =>
    @write action: 'auth'
    CineIOPeer._sendIdentity() if CineIOPeer.config.identity
    CineIOPeer._sendJoinRoom(room) for room in CineIOPeer.config.rooms

  _connectionEnded: ->
    debug("Connection closed")

  _callFromRoom: (room, options)->
    @calls[room] ||= new CallObject(room, options)
    @calls[room]

  _signalHandler: (data)=>
    # debug("got data")
    switch data.action
      # BASE
      when 'error'
        CineIOPeer.trigger('error', data)

      when 'rtc-servers'
        debug('setting config', data)
        @iceServers = data.data
        @fetchedIce = true
        CineIOPeer.trigger('gotIceServers', data.data)

      when 'ack'
        if data.source == 'call'
          CineIOPeer.config.rooms.push(data.room)
          callObj = @_callFromRoom(data.room, initiated: true, called: data.otheridentity)
          CineIOPeer.trigger('call-placed', call: callObj, otheridentity: data.otheridentity)
      # END BASE

      # CALLING
      when 'call'
        # debug('got incoming call', data)
        CineIOPeer.trigger('call', identity: data.identity, call: @_callFromRoom(data.room))

      # created from initiator
      when 'call-cancel'
        # debug('got incoming call', data)
        @_callFromRoom(data.room).trigger('call-cancel', identity: data.identity)

      # created from recipient
      when 'call-reject'
        # debug('got incoming call', data)
        @_callFromRoom(data.room).trigger('call-reject', identity: data.identity)
      # END CALLING

      # ROOMS
      when 'room-leave'
        debug('room-leave', data)
        @_callFromRoom(data.room).left(data.identity) if data.identity
        @write action: 'room-goodbye', sparkId: data.sparkId, data.room
        @_closePeerConnection(data)

      when 'room-join'
        debug('room-join', data)
        @_callFromRoom(data.room).joined(data.identity) if data.identity
        @_ensurePeerConnection data, offer: true, support: data.support
        @write action: 'room-announce', sparkId: data.sparkId, room: data.room

      when 'room-announce'
        debug('room-announce', data)
        @_ensurePeerConnection data, offer: false, support: data.support

      when 'room-goodbye'
        debug("room-goodbye", data)
        @_closePeerConnection(data)
      # END ROOMS

      # RTC
      when 'rtc-ice'
        # debug('got remote ice', data)
        return unless data.sparkId
        @_ensurePeerConnection data, offer: false, support: data.support, (err, pc)->
          pc.processIce(data.candidate)

      when 'rtc-offer'
        debug('got offer', data)
        @_ensurePeerConnection data, offer: false, support: data.support, (err, pc)=>
          pc.handleOffer data.offer, (err)=>
            debug('handled offer', err)
            handleAnswer = (err, answer)=>
              actuallySendAnswer = =>
                # no harm in always overwriting the offer sdp with the local description
                answer.sdp = pc.pc.localDescription.sdp
                @write action: 'rtc-answer', answer: answer, sparkId: data.sparkId
                # debug('handling answer', answer, pc.pc.localDescription.sdp)

              # if the peer connection has not gotten the list of candidates
              # and it does not support trickle ice,
              # then wait for the ice and then send the answer
              if !pc.gotEndOfCandidates && pc.support.trickleIce == false
                console.log("waiting for endOfCandidates")
                pc.once 'endOfCandidates', actuallySendAnswer
              else
                console.log("not waiting for end of candidates")
                actuallySendAnswer()

            pc.answer handleAnswer


      when 'rtc-answer'
        # debug('got answer', data)
        @_ensurePeerConnection data, offer: false, support: data.support, (err, pc)->
          pc.handleAnswer(data.answer)
      # END RTC
      # else
        # debug("UNKNOWN DATA", data)
  _closePeerConnection: (data)=>
    otherClientUUID = data.sparkUUID
    return unless @peerConnections[otherClientUUID]
    return if @peerConnections[otherClientUUID] == PENDING
    @peerConnections[otherClientUUID].close()
    delete @peerConnections[otherClientUUID]

  _sendOffer: (peerConnection)=>
    response = (err, offer)=>
      otherClientSparkId = peerConnection.otherClientSparkId
      if err || !offer
        debug("FATAL ERROR in offer", err, offer)
        return CineIOPeer.trigger("error", kind: 'offer', fatal: true, err: err)

      reallySendOffer = =>
        debug('offering', err, otherClientSparkId, offer)
        # no harm in always overwriting the offer sdp with the local description
        offer.sdp = peerConnection.pc.localDescription.sdp
        @write action: 'rtc-offer', offer: offer, sparkId: otherClientSparkId

      # if the peer connection has not gotten the list of candidates
      # and it does not support trickle ice,
      # then wait for the ice and then send the offer
      if !peerConnection.gotEndOfCandidates && peerConnection.support.trickleIce == false
        peerConnection.once 'endOfCandidates', reallySendOffer
      else
        reallySendOffer()

    # av = CineIOPeer.localStreams().length == 0
    constraints =
      mandatory:
        OfferToReceiveAudio: true
        OfferToReceiveVideo: true
    if peerConnection.mainDataChannel
      constraints.optional = [{RtpDataChannels: true}]
    peerConnection.offer constraints, response

  _onCloseOfPeerConnection: (peerConnection)->
    # debug("remote closed", event)
    return unless peerConnection.videoEls
    for videoEl in peerConnection.videoEls
      CineIOPeer.trigger 'media-removed',
        peerConnection: peerConnection
        videoElement: videoEl
        remote: true
    delete peerConnection.videoEls

  _newMember: (otherClientUUID, otherClientSparkId, options, callback)=>
    # we must be pending to get ice candidates, do not create a new pc
    if @peerConnections[otherClientUUID]
      return @_ensureReady =>
        callback(null, @peerConnections[otherClientUUID])

    @peerConnections[otherClientUUID] = PENDING
    @_ensureReady =>
      debug("CREATING NEW PEER CONNECTION!!", otherClientUUID, options)
      peerConnection = PeerConnectionFactory.create()
      @peerConnections[otherClientUUID] = peerConnection
      peerConnection.videoEls = []

      peerConnection.support = options.support || {}

      setSparkIdOnPeerConnection(peerConnection, otherClientSparkId)
      peerConnection.addStream(stream) for stream in CineIOPeer.localStreams()

      peerConnection.on 'addStream', (event)->
        debug("got remote stream", event)
        videoEl = CineIOPeer._createVideoElementFromStream(event.stream, muted: false, mirror: false)
        peerConnection.videoEls.push videoEl
        CineIOPeer.trigger 'media-added',
          peerConnection: peerConnection
          videoElement: videoEl
          remote: true

      peerConnection.on 'removeStream', (event)->
        debug("removing remote stream", event)
        videoEl = CineIOPeer._getVideoElementFromStream(event.stream)
        index = peerConnection.videoEls.indexOf(videoEl)
        peerConnection.videoEls.splice(index, 1) if index > -1

        CineIOPeer.trigger 'media-removed',
          peerConnection: peerConnection
          videoElement: videoEl
          remote: true

      peerConnection.on 'addChannel', (dataChannel)=>
        debug("GOT A NEW DATA CHANNEL", dataChannel)
        peerConnection.mainDataChannel = @_prepareDataChannel(peerConnection, dataChannel)

      peerConnection.on 'ice', (candidate)=>
        return if peerConnection.support.trickleIce == false
        # debug('got my ice', candidate.candidate.candidate)
        @write action: 'rtc-ice', candidate: candidate, sparkId: peerConnection.otherClientSparkId

      # unlikely there will be a mainDataChannel but good to check as we would want to offer
      if options.offer && CineIOPeer.localStreams().length > 0 || peerConnection.mainDataChannel
        @_sendOffer(peerConnection)
      peerConnection.on 'endOfCandidates', (event)->
        debug("got end of candidates")
        peerConnection.gotEndOfCandidates = true
      peerConnection.on 'close', (event)=>
        @_onCloseOfPeerConnection(peerConnection)
        delete @peerConnections[otherClientUUID]

      callback(null, peerConnection)
      CineIOPeer.trigger("peerConnectionMade")

  _ensurePeerConnection: (data, options, callback=noop)=>
    otherClientSparkId = data.sparkId
    otherClientUUID = data.sparkUUID
    candidate = @peerConnections[otherClientUUID]
    if candidate && candidate != PENDING
      # the sparkID might have changed because the other client reconnected
      setSparkIdOnPeerConnection(candidate, otherClientSparkId)
      return setTimeout ->
        callback null, candidate
    @_newMember(otherClientUUID, otherClientSparkId, options, callback)

  _ensureReady: (callback)=>
    @_ensureIce callback

  _ensureIce: (callback)=>
    return setTimeout callback if @fetchedIce
    CineIOPeer.once 'gotIceServers', callback

exports.connect = (options)->
  new Connection(options)

CineIOPeer = require('./main')
CallObject = require('./call')
