PeerConnection = require('rtcpeerconnection')

remotePeerConnection = null

# gotMyIce = (candidate)->


gotRemoteStream = (event)->
  console.log('got stream yooo')
  videoEl = CineIOPeer._createVideoElementFromStream(event.stream)
  document.body.appendChild(videoEl)

handleLocalOffer = (err, offer)->
  # this would be where we send the offer to the signaling server
  remotePeerConnection.handleOffer offer, (err)->
    console.log('handled remote offer', arguments)
    remotePeerConnection.answer (err, answer)->
      console.log('answering remote', arguments)
      peerConnection.handleAnswer(answer)

module.exports = (name, to, stream)->
  console.log('I am', name)
  console.log('Connecting to', to)
  # remotePeerConnection = new PeerConnection(config)

  localConnection = signalingConnection()
  localConnection.emit('name', name: name)
  localConnection.on 'allservers', (config)->
    console.log('setting config', config)
    peerConnection = new PeerConnection(config)
    peerConnection.on('addStream', gotRemoteStream)
    peerConnection.addStream(stream)

    peerConnection.on 'ice', (candidate)->
      console.log('got my ice', candidate)

      localConnection.emit('ice', candidate: candidate, name: to)

    if name =='tom'
      peerConnection.offer (err, offer)->
        console.log('offering')
        localConnection.emit('offer', offer: offer, name: to)

    localConnection.on 'ice', (candidate)->
      console.log('got remote ice', candidate)
      peerConnection.processIce(candidate)

    localConnection.on 'offer', (offer)->
      console.log('got offer', offer)
      peerConnection.handleOffer offer, (err)->
        console.log('handled offer', err)
        peerConnection.answer (err, answer)->
          localConnection.emit('answer', answer: answer, name: to)

    localConnection.on 'answer', (answer)->
      console.log('got answer', answer)
      peerConnection.handleAnswer(answer)

  # remoteConnection = signalingConnection()


  # remotePeerConnection.on 'ice', (candidate)->
  #   console.log('got remote ice', candidate)
  #   remoteConnection.send('ice', candidate)



CineIOPeer = require('./main')
signalingConnection = require('./signaling_connection')
