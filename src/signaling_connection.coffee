PeerConnection = require('rtcpeerconnection')

newConnection = ->
  Primus.connect('http://localhost:8888')

peerConnections = {}

exports.connect = ->
  primus = newConnection()
  iceServers = null
  fetchedIce = false

  ensureIce = (callback)->
    return callback() if fetchedIce
    CineIOPeer.on 'gotIceServers', callback

  primus.on 'data', (data)->
    console.log('got data', data)
    switch data.action
      when 'allservers'
        console.log('setting config', data)
        iceServers = data.data
        fetchedIce = true
        CineIOPeer.trigger('gotIceServers')

      when 'leave'
        console.log('leaving', data)
        peerConnections[data.sparkId].close()
        peerConnections[data.sparkId] = null

      when 'member'
        console.log('got new member', data)
        newMember(data.sparkId, offer: true)

      when 'members'
        console.log('got members', data)
        # for member in data.members
        #   newMember(member, offer: true)

      when 'ice'
        console.log('got remote ice', data)
        peerConnections[data.sparkId].processIce(data.candidate)

      when 'offer'
        roomSparkId = data.sparkId
        console.log('got offer', data)
        pc = newMember(data.sparkId, offer: false)
        pc.handleOffer data.offer, (err)->
          console.log('handled offer', err)
          peerConnections[data.sparkId].answer (err, answer)->
            primus.write action: 'answer', answer: answer, sparkId: roomSparkId

      when 'answer'
        console.log('got answer', data)
        peerConnections[data.sparkId].handleAnswer(data.answer)

  newMember = (roomSparkId, options)->
    ensureIce ->
      peerConnection = new PeerConnection(iceServers: iceServers)
      peerConnection.on 'ice', (candidate)->
        console.log('got my ice', candidate.candidate.candidate)
        primus.write action: 'ice', candidate: candidate, sparkId: roomSparkId

      peerConnection.addStream(CineIOPeer.stream)

      peerConnection.on 'addStream', (event)->
        console.log("got remote stream", event)
        videoEl = CineIOPeer._createVideoElementFromStream(event.stream, muted: false)
        peerConnection.videoEl = videoEl
        CineIOPeer.trigger 'streamAdded',
          peerConnection: peerConnection
          videoElement: videoEl

      peerConnection.on 'close', (event)->
        console.log("remote closed", event)
        peerConnection.videoEl.remove()
        CineIOPeer.trigger 'streamRemoved', peerConnection: peerConnection

      if options.offer
        console.log('sending offer')
        peerConnection.offer (err, offer)->
          console.log('offering')
          primus.write action: 'offer', offer: offer, sparkId: roomSparkId

      peerConnections[roomSparkId] = peerConnection

  return primus

CineIOPeer = require('./main')
