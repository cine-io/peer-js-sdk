module.exports = ->
  beforeEach ->
    CineIOPeer.reset()

  afterEach ->
    delete CineIOPeer._signalConnection
    delete CineIOPeer.microphoneStream
    delete CineIOPeer.cameraStream
    delete CineIOPeer.cameraAndMicrophoneStream
    delete CineIOPeer.screenShareStream
