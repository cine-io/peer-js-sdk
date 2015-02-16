PeerConnectionFactory = require('../src/peer_connection_factory')
CineIOPeer = require('../src/main')
FakePeerConnection = require('./helpers/fake_peer_connection')
setupAndTeardown = require('./helpers/setup_and_teardown')
debug = require('../src/debug')('cine:peer:peer_connection_factory_test')

describe 'PeerConnectionFactory', ->
  setupAndTeardown()

  beforeEach ->
    sinon.stub PeerConnectionFactory, '_actuallyCreatePeerConnection', (options)=>
      if @fakeConnection
        debug("ugh fakeConnection")
        throw new Error("Two connections made!!!")
      @fakeConnection = new FakePeerConnection(options)

  afterEach ->
    PeerConnectionFactory._actuallyCreatePeerConnection.restore()
    PeerConnectionFactory._reset()

  describe 'create', ->
    it 'requires the ice servers', ->
      expect(PeerConnectionFactory.create()).to.be.null
    describe 'after getting ice servers', ->
      beforeEach ->
        CineIOPeer.trigger('gotIceServers', some: 'ice data')
      it 'creates a connection', ->
        connection = PeerConnectionFactory.create()
        expect(connection).to.be.instanceof(FakePeerConnection)
        expect(connection.options).to.deep.equal(iceServers: {some: 'ice data'})
