PeerConnection = require('rtcpeerconnection')

newConnection = ->
  io.connect('http://localhost:8888')

gotRemoteStream = (event)->
  console.log('got stream yooo', event)
  videoEl = CineIOPeer._createVideoElementFromStream(event.stream, muted: true)
  document.body.appendChild(videoEl)

peerConnections = {}

exports.connect = (name, room, stream)->
  signalConnection = newConnection()
  iceServers = null

  signalConnection.emit 'name', name: name

  signalConnection.on 'allservers', (data)->
    console.log('setting config', data)
    iceServers = data
    signalConnection.emit 'join', room: room

  newMember = (member, options)->
    roomMember = member.name
    peerConnection = new PeerConnection(iceServers: iceServers)
    peerConnection.on 'ice', (candidate)->
      console.log('got my ice', candidate.candidate.candidate)
      signalConnection.emit('ice', candidate: candidate, name: roomMember)

    peerConnection.addStream(stream)

    peerConnection.on 'addStream', (event)->
      console.log("got remote stream", event)
      CineIOPeer.remoteStreamAdded(peerConnection, event.stream)

    if options.offer
      console.log('sending offer')
      peerConnection.offer (err, offer)->
        console.log('offering')
        signalConnection.emit('offer', offer: offer, name: roomMember)


    peerConnections[roomMember] = peerConnection

  signalConnection.on 'member', (data)->
    console.log('got new member', data)
    newMember(data, offer: false)

  signalConnection.on 'members', (data)->
    console.log('got members', data)
    for member in data.members
      newMember(member, offer: true)

  signalConnection.on 'ice', (data)->
    console.log('got remote ice', data)
    peerConnections[data.name].processIce(data.candidate)

  signalConnection.on 'offer', (data)->
    roomMember = data.name
    console.log('got offer', data)
    peerConnections[data.name].handleOffer data.offer, (err)->
      console.log('handled offer', err)
      peerConnections[data.name].answer (err, answer)->
        signalConnection.emit('answer', answer: answer, name: roomMember)

  signalConnection.on 'answer', (data)->
    console.log('got answer', data)
    peerConnections[data.name].handleAnswer(data.answer)

  return signalConnection

CineIOPeer = require('./main')
