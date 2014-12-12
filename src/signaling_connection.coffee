PeerConnection = require('rtcpeerconnection')
uuid = require('./vendor/uuid')

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
    data.source = 'web'
    data.publicKey = CineIOPeer.config.publicKey
    data.uuid = @myUUID
    data.identity = CineIOPeer.config.identity.identity if CineIOPeer.config.identity
    console.log("Writing", data)
    @primus.write(arguments...)

  addLocalStream: (stream, options={})=>
    for otherClientUUID, peerConnection of @peerConnections
      console.log "adding local stream #{stream.id} to #{otherClientUUID}"
      peerConnection.addStream(stream)
      # need to reoffer every time there's a new stream
      # http://stackoverflow.com/questions/16015022/webrtc-how-to-add-stream-after-offer-and-answer
      @_sendOffer(peerConnection) unless options.silent

  removeLocalStream: (stream, options={})=>
    for otherClientUUID, peerConnection of @peerConnections
      console.log "removing local stream #{stream.id} from #{otherClientUUID}"
      peerConnection.removeStream(stream)
      @_sendOffer(peerConnection) unless options.silent

  sendDataToAllPeers: (data)->
    for otherClientUUID, peerConnection of @peerConnections
      console.log "sending data #{data} to #{otherClientUUID}"
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
      console.log("ON OPEN", event)
      if dataChannel.readyState == "open"
        for data in dataChannel.dataToSend
          console.log("Actually sending data", data)
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
    console.log("Connection closed")

  _callFromRoom: (initiated, data)->
    @calls[data.room] ||= new CallObject(initiated, data)
    @calls[data.room]

  _signalHandler: (data)=>
    # console.log("got data")
    switch data.action
      # BASE
      when 'error'
        CineIOPeer.trigger('error', data)

      when 'rtc-servers'
        console.log('setting config', data)
        @iceServers = data.data
        @fetchedIce = true
        CineIOPeer.trigger('gotIceServers')

      when 'ack'
        if data.source == 'call'
          CineIOPeer.config.rooms.push(data.room)
          CineIOPeer.trigger('call-placed', call: @_callFromRoom(true, data))
      # END BASE

      # CALLING
      when 'call'
        # console.log('got incoming call', data)
        CineIOPeer.trigger('call', call: @_callFromRoom(false, data))

      when 'call-reject'
        # console.log('got incoming call', data)
        CineIOPeer.trigger('call-reject', call: @_callFromRoom(false, data))
      # END CALLING

      # ROOMS
      when 'room-leave'
        console.log('room-leave', data)
        @write action: 'room-goodbye', sparkId: data.sparkId, data.room
        @_closePeerConnection(data)

      when 'room-join'
        console.log('room-join', data)
        @_ensurePeerConnection data, offer: true
        @write action: 'room-announce', source: "web", sparkId: data.sparkId, room: data.room

      when 'room-announce'
        console.log('room-announce', data)
        @_ensurePeerConnection data, offer: false

      when 'room-goodbye'
        console.log("room-goodbye", data)
        @_closePeerConnection(data)
      # END ROOMS

      # RTC
      when 'rtc-ice'
        #console.log('got remote ice', data)
        return unless data.sparkId
        @_ensurePeerConnection data, offer: false, (err, pc)=>
          pc.processIce(data.candidate)

      when 'rtc-offer'
        console.log('got offer', data)
        @_ensurePeerConnection data, offer: false, (err, pc)=>
          pc.handleOffer data.offer, (err)=>
            # console.log('handled offer', err)
            answerResponse = (err, answer)=>
              @write action: 'rtc-answer', answer: answer, sparkId: data.sparkId
            if CineIOPeer.localStreams().length == 0
              # pc.answerBroadcastOnly answerResponse
              pc.answer answerResponse
            else
              pc.answer answerResponse

      when 'rtc-answer'
        # console.log('got answer', data)
        @_ensurePeerConnection data, offer: false, (err, pc)->
          pc.handleAnswer(data.answer)
      # END RTC
      # else
      #   console.log("UNKNOWN DATA", data)
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
        console.log("FATAL ERROR in offer", err, offer)
        return CineIOPeer.trigger("error", kind: 'offer', fatal: true, err: err)
      console.log('offering', err, otherClientSparkId, offer)
      @write action: 'rtc-offer', offer: offer, sparkId: otherClientSparkId
    # av = CineIOPeer.localStreams().length == 0
    constraints =
      mandatory:
        OfferToReceiveAudio: true
        OfferToReceiveVideo: true
    if peerConnection.mainDataChannel
      constraints.optional = [{RtpDataChannels: true}]
    peerConnection.offer constraints, response

  _onCloseOfPeerConnection: (peerConnection)->
      # console.log("remote closed", event)
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
      console.log("CREATING NEW PEER CONNECTION!!", otherClientUUID, options)
      peerConnection = @_initializeNewPeerConnection(iceServers: @iceServers)
      @peerConnections[otherClientUUID] = peerConnection
      peerConnection.videoEls = []
      setSparkIdOnPeerConnection(peerConnection, otherClientSparkId)
      peerConnection.addStream(stream) for stream in CineIOPeer.localStreams()

      peerConnection.on 'addStream', (event)->
        console.log("got remote stream", event)
        videoEl = CineIOPeer._createVideoElementFromStream(event.stream, muted: false, mirror: false)
        peerConnection.videoEls.push videoEl
        CineIOPeer.trigger 'media-added',
          peerConnection: peerConnection
          videoElement: videoEl
          remote: true

      peerConnection.on 'removeStream', (event)->
        console.log("removing remote stream", event)
        videoEl = CineIOPeer._getVideoElementFromStream(event.stream)
        index = peerConnection.videoEls.indexOf(videoEl)
        peerConnection.videoEls.splice(index, 1) if index > -1

        CineIOPeer.trigger 'media-removed',
          peerConnection: peerConnection
          videoElement: videoEl
          remote: true

      peerConnection.on 'addChannel', (dataChannel)=>
        console.log("GOT A NEW DATA CHANNEL", dataChannel)
        peerConnection.mainDataChannel = @_prepareDataChannel(peerConnection, dataChannel)

      peerConnection.on 'ice', (candidate)=>
        #console.log('got my ice', candidate.candidate.candidate)
        @write action: 'rtc-ice', candidate: candidate, sparkId: peerConnection.otherClientSparkId

      # unlikely there will be a mainDataChannel but good to check as we would want to offer
      if options.offer && CineIOPeer.localStreams().length > 0 || peerConnection.mainDataChannel
        @_sendOffer(peerConnection)

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

  _initializeNewPeerConnection: (options)->
    new PeerConnection(options)

exports.connect = (options)->
  new Connection(options)

CineIOPeer = require('./main')
CallObject = require('./call')
