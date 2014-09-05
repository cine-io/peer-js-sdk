PeerConnection = require('rtcpeerconnection')
config =
  iceServers:[{}]

config = null

localPeerConnection = null
remotePeerConnection = null

gotMyIce = (candidate)->
  console.log('got my ice', candidate)
  remotePeerConnection.processIce(candidate)

gotRemoteIce = (candidate)->
  console.log('got remote ice', candidate)
  localPeerConnection.processIce(candidate)

gotRemoteStream = (event)->
  videoEl = CineIOPeer._createVideoElementFromStream(event.stream)
  document.body.appendChild(videoEl)

handleLocalOffer = (err, offer)->
  # this would be where we send the offer to the signaling server
  remotePeerConnection.handleOffer offer, (err)->
    console.log('handled remote offer', arguments)
    remotePeerConnection.answer (err, answer)->
      console.log('answering remote', arguments)
      localPeerConnection.handleAnswer(answer)

globStream = null
module.exports = (stream)->
  globStream = stream
  localPeerConnection = new PeerConnection(config)
  remotePeerConnection = new PeerConnection(config)
  localPeerConnection.on('ice', gotMyIce)
  remotePeerConnection.on('ice', gotRemoteIce)

  localPeerConnection.addStream(stream)

  remotePeerConnection.on('addStream', gotRemoteStream)

  localPeerConnection.offer(handleLocalOffer)

CineIOPeer = require('./main')
