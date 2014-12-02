module.exports = ->
  beforeEach ->
    CineIOPeer.reset()

  afterEach ->
    delete CineIOPeer._signalConnection
    delete CineIOPeer.stream
