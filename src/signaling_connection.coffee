PeerConnection = require('rtcpeerconnection')
Primus = require('./vendor/primus')
Config = require('./config')
noop = ->
connectToCineSignaling = ->
  Primus.connect(Config.signalingServer)

PENDING = 1

sendToDataChannel = (dataChannel, data)->
  return dataChannel.send(JSON.stringify(data)) if dataChannel.readyState == 'open'
  dataChannel.dataToSend.push data

class Connection
  constructor: (@options)->
    @iceServers = null
    @fetchedIce = false
    @peerConnections = {}
    @calls = {}
    @primus = connectToCineSignaling()
    @primus.on 'open', @_sendPublicKey
    @primus.on 'data', @_signalHandler
    @primus.on 'end', @_connectionEnded

  write: =>
    @primus.write(arguments...)

  addLocalStream: (stream, options={})=>
    for otherClientSparkId, peerConnection of @peerConnections
      console.log "adding local stream #{stream.id} to #{otherClientSparkId}"
      peerConnection.addStream(stream)
      # need to reoffer every time there's a new stream
      # http://stackoverflow.com/questions/16015022/webrtc-how-to-add-stream-after-offer-and-answer
      @_sendOffer(otherClientSparkId, peerConnection) unless options.silent

  removeLocalStream: (stream, options={})=>
    for otherClientSparkId, peerConnection of @peerConnections
      console.log "removing local stream #{stream.id} from #{otherClientSparkId}"
      peerConnection.removeStream(stream)
      @_sendOffer(otherClientSparkId, peerConnection) unless options.silent

  sendDataToAllPeers: (data)->
    for otherClientSparkId, peerConnection of @peerConnections
      console.log "sending data #{data} to #{otherClientSparkId}"
      @_sendDataToPeer(peerConnection, otherClientSparkId, data)

  _sendDataToPeer: (peerConnection, otherClientSparkId, data)->
    unless peerConnection.mainDataChannel
      peerConnection.mainDataChannel = @_newDataChannel(peerConnection, otherClientSparkId)
      @_sendOffer(otherClientSparkId, peerConnection)
    @dataChannel = peerConnection.mainDataChannel
    sendToDataChannel peerConnection.mainDataChannel, action: 'userData', data: data

  _newDataChannel: (peerConnection, otherClientSparkId)->
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

  _sendPublicKey: =>
    @write action: 'auth', publicKey: @options.publicKey

  _connectionEnded: ->
    console.log("Connection closed")

  _callFromRoom: (initiated, data)->
    @calls[data.room] ||= new CallObject(initiated, data)
    @calls[data.room]

  _signalHandler: (data)=>
    # console.log("got data")
    switch data.action
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

      when 'call'
        # console.log('got incoming call', data)
        CineIOPeer.trigger('call', call: @_callFromRoom(false, data))

      when 'call-reject'
        # console.log('got incoming call', data)
        CineIOPeer.trigger('call-reject', call: @_callFromRoom(false, data))

      when 'room-leave'
        console.log('room-leave', data)
        @write action: 'room-goodbye', source: "web", sparkId: data.sparkId
        return unless @peerConnections[data.sparkId]
        return if @peerConnections[data.sparkId] == PENDING
        @peerConnections[data.sparkId].close()
        delete @peerConnections[data.sparkId]

      when 'room-join'
        console.log('room-join', data)
        @_ensurePeerConnection(data.sparkId, offer: true)
        @write action: 'room-announce', source: "web", sparkId: data.sparkId

      when 'room-announce'
        console.log('room-announce', data)
        @_ensurePeerConnection(data.sparkId, offer: false)

      when 'room-goodbye'
        console.log("room-goodbye", data)
        return unless @peerConnections[data.sparkId]
        return if @peerConnections[data.sparkId] == PENDING
        peerConnection = @peerConnections[data.sparkId]
        peerConnection.close()
        delete @peerConnections[data.sparkId]

      # peerConnection standard config
      when 'rtc-ice'
        #console.log('got remote ice', data)
        return unless data.sparkId
        @_ensurePeerConnection data.sparkId, offer: false, (err, pc)=>
          pc.processIce(data.candidate)

      # peerConnection standard config
      when 'rtc-offer'
        otherClientSparkId = data.sparkId
        console.log('got offer', data)
        @_ensurePeerConnection otherClientSparkId, offer: false, (err, pc)=>
          pc.handleOffer data.offer, (err)=>
            # console.log('handled offer', err)
            answerResponse = (err, answer)=>
              @write action: 'rtc-answer', source: "web", answer: answer, sparkId: otherClientSparkId
            if CineIOPeer.localStreams().length == 0
              # pc.answerBroadcastOnly answerResponse
              pc.answer answerResponse
            else
              pc.answer answerResponse

      # peerConnection standard config
      when 'rtc-answer'
        # console.log('got answer', data)
        @_ensurePeerConnection data.sparkId, offer: false, (err, pc)->
          pc.handleAnswer(data.answer)
      # else
      #   console.log("UNKNOWN DATA", data)
  _sendOffer: (otherClientSparkId, peerConnection)=>
    response = (err, offer)=>
      if err || !offer
        console.log("FATAL ERROR in offer", err, offer)
        return CineIOPeer.trigger("error", kind: 'offer', fatal: true, err: err)
      console.log('offering', err, otherClientSparkId, offer)
      @write action: 'rtc-offer', source: "web", offer: offer, sparkId: otherClientSparkId
    av = CineIOPeer.localStreams().length == 0
    constraints =
      mandatory:
        OfferToReceiveAudio: av
        OfferToReceiveVideo: av
      optional: [{
        RtpDataChannels: peerConnection.mainDataChannel?
      }]
    peerConnection.offer constraints, response

  _onCloseOfPeerConnection: (peerConnection)->
      # console.log("remote closed", event)
      return unless peerConnection.videoEls
      for videoEl in peerConnection.videoEls
        CineIOPeer.trigger 'mediaRemoved',
          peerConnection: peerConnection
          videoElement: videoEl
          remote: true
      delete peerConnection.videoEls

  _newMember: (otherClientSparkId, options, callback)=>
    # we must be pending to get ice candidates, do not create a new pc
    if @peerConnections[otherClientSparkId]
      return @_ensureReady =>
        callback(null, @peerConnections[otherClientSparkId])

    @peerConnections[otherClientSparkId] = PENDING
    @_ensureReady =>
      console.log("CREATING NEW PEER CONNECTION!!", otherClientSparkId, options)
      peerConnection = @_initializeNewPeerConnection(iceServers: @iceServers)
      @peerConnections[otherClientSparkId] = peerConnection
      peerConnection.videoEls = []
      peerConnection.addStream(stream) for stream in CineIOPeer.localStreams()

      peerConnection.on 'addStream', (event)->
        console.log("got remote stream", event)
        videoEl = CineIOPeer._createVideoElementFromStream(event.stream, muted: false, mirror: false)
        peerConnection.videoEls.push videoEl
        CineIOPeer.trigger 'mediaAdded',
          peerConnection: peerConnection
          videoElement: videoEl
          remote: true

      peerConnection.on 'removeStream', (event)->
        console.log("removing remote stream", event)
        videoEl = CineIOPeer._getVideoElementFromStream(event.stream)
        index = peerConnection.videoEls.indexOf(videoEl)
        peerConnection.videoEls.splice(index, 1) if index > -1

        CineIOPeer.trigger 'mediaRemoved',
          peerConnection: peerConnection
          videoElement: videoEl
          remote: true

      peerConnection.on 'addChannel', (dataChannel)=>
        console.log("GOT A NEW DATA CHANNEL", dataChannel)
        peerConnection.mainDataChannel = @_prepareDataChannel(peerConnection, dataChannel)

      peerConnection.on 'ice', (candidate)=>
        #console.log('got my ice', candidate.candidate.candidate)
        @write action: 'rtc-ice', source: "web", candidate: candidate, sparkId: otherClientSparkId

      if options.offer
        @_sendOffer(otherClientSparkId, peerConnection)

      peerConnection.on 'close', (event)=>
        @_onCloseOfPeerConnection(peerConnection)
        delete @peerConnections[otherClientSparkId]

      callback(null, peerConnection)
      CineIOPeer.trigger("peerConnectionMade")

  _ensurePeerConnection: (otherClientSparkId, options, callback=noop)=>
    candidate = @peerConnections[otherClientSparkId]
    if candidate && candidate != PENDING
      return setTimeout ->
        callback null, candidate
    @_newMember(otherClientSparkId, options, callback)

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
