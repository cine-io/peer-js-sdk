PeerConnection = require('rtcpeerconnection')
Primus = require('./vendor/primus')

newConnection = ->
  Primus.connect('http://localhost:8888')

peerConnections = {}

exports.connect = ->
  primus = newConnection()
  iceServers = null
  fetchedIce = false

  ensurePeerConnection = (otherClientSparkId, options)->
    return peerConnections[otherClientSparkId] if peerConnections[otherClientSparkId]
    console.log("CREATING NEW PEER CONNECTION!!", otherClientSparkId, options)
    peerConnections[otherClientSparkId] = newMember(otherClientSparkId, options)

  ensureIce = (callback)->
    return callback() if fetchedIce
    CineIOPeer.on 'gotIceServers', callback

  primus.on 'data', (data)->
    switch data.action
      when 'allservers'
        console.log('setting config', data)
        iceServers = data.data
        fetchedIce = true
        CineIOPeer.trigger('gotIceServers')

      when 'incomingcall'
        console.log('got incoming call', data)
        CineIOPeer.trigger('incomingcall', call: new CallObject(data))

      when 'leave'
        console.log('leaving', data)
        return unless peerConnections[data.sparkId]
        peerConnections[data.sparkId].close()
        peerConnections[data.sparkId] = null

      when 'member'
        console.log('got new member', data)
        ensurePeerConnection(data.sparkId, offer: true)

      # peerConnection standard config
      when 'ice'
        console.log('got remote ice', data)
        ensurePeerConnection(data.sparkId, offer: false).processIce(data.candidate)

      # peerConnection standard config
      when 'offer'
        otherClientSparkId = data.sparkId
        console.log('got offer', data)
        ensurePeerConnection(otherClientSparkId, offer: false).handleOffer data.offer, (err)->
          console.log('handled offer', err)
          peerConnections[otherClientSparkId].answer (err, answer)->
            primus.write action: 'answer', source: "web", answer: answer, sparkId: otherClientSparkId

      # peerConnection standard config
      when 'answer'
        console.log('got answer', data)
        ensurePeerConnection(data.sparkId, offer: false).handleAnswer(data.answer)
      else
        console.log("UNKNOWN DATA", data)

  newMember = (otherClientSparkId, options)->
    ensureIce ->
      peerConnection = new PeerConnection(iceServers: iceServers)
      console.log("CineIOPeer.stream", CineIOPeer.stream)
      if CineIOPeer.stream
        peerConnection.addStream(CineIOPeer.stream)
      else
        console.warn("No stream attached")

      peerConnection.on 'addStream', (event)->
        console.log("got remote stream", event)
        videoEl = CineIOPeer._createVideoElementFromStream(event.stream, muted: false, mirror: false)
        peerConnection.videoEl = videoEl
        CineIOPeer.trigger 'streamAdded',
          peerConnection: peerConnection
          videoElement: videoEl

      peerConnection.on 'ice', (candidate)->
        console.log('got my ice', candidate.candidate.candidate)
        primus.write action: 'ice', source: "web", candidate: candidate, sparkId: otherClientSparkId

      if options.offer
        console.log('sending offer')
        peerConnection.offer (err, offer)->
          console.log('offering')
          primus.write action: 'offer', source: "web", offer: offer, sparkId: otherClientSparkId


      peerConnection.on 'close', (event)->
        console.log("remote closed", event)
        peerConnection.videoEl.remove() if peerConnection.videoEl
        CineIOPeer.trigger 'streamRemoved', peerConnection: peerConnection

  return primus

CineIOPeer = require('./main')
CallObject = require('./call')
