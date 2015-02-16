async = require('async')
CineIOPeer = require('../src/main')
BroadcastBridge = require('../src/broadcast_bridge')
nearestServer = require('../src/nearest_server')
PeerConnectionFactory = require('../src/peer_connection_factory')
setupAndTeardown = require('./helpers/setup_and_teardown')
stubPrimus = require('./helpers/stub_primus')
FakePeerConnection = require('./helpers/fake_peer_connection')
FakeMediaStream = require('./helpers/fake_media_stream')
debug = require('../src/debug')('cine:peer:broadcast_bridge_test')

describe 'BroadcastBridge', ->
  setupAndTeardown()
  stubPrimus()

  beforeEach ->
    sinon.stub PeerConnectionFactory, 'create', =>
      if @fakeConnection
        debug("ugh fakeConnection")
        throw new Error("Two connections made!!!")
      @fakeConnection = new FakePeerConnection()

  afterEach ->
    PeerConnectionFactory.create.restore()
    PeerConnectionFactory._reset()

  afterEach ->
    if @fakeConnection
      debug("deleting fakeConnection", @fakeConnection)
      delete @fakeConnection

  describe 'constructor', ->
    it 'waits for ice servers', ->
      bb = new BroadcastBridge(CineIOPeer)
      CineIOPeer.trigger('gotIceServers', some: 'ice data')
      expect(bb.iceReady).to.be.true

    it 'creates a connection', ->
      bb = new BroadcastBridge(CineIOPeer)
      CineIOPeer.trigger('gotIceServers', some: 'ice data')
      expect(bb.connection).to.be.ok
      expect(bb.connection.connected).to.be.false

  describe 'methods', ->
    beforeEach ->
      @jsonpStub = sinon.stub nearestServer, '_makeJsonpCall'
      @jsonpStub.callsArgWith 1, null, {rtcPublish: 'http://some-broadcast-bridge-url'}

    afterEach ->
      @jsonpStub.restore()
      nearestServer._reset()

    beforeEach ->
      CineIOPeer.config.publicKey = 'project-public-key'

    beforeEach ->
      @subject = new BroadcastBridge(CineIOPeer)

    describe '#startBroadcast', ->
      beforeEach ->
        CineIOPeer.trigger('gotIceServers', some: 'ice data')

      beforeEach (done)->
        streamType = 'camera'
        @mediaStream = new FakeMediaStream
        streamId = 'the stream id'
        streamKey = 'the stream key'
        @subject.startBroadcast streamType, @mediaStream, streamId, streamKey, done

        fakeConnectionMade = false
        testFunction = -> fakeConnectionMade
        checkFunction = (callback)=>
          if @fakeConnection && @fakeConnection.offered
            @subject.connection.primus.trigger 'open'
            fakeConnectionMade = true
          setTimeout(callback, 10)
        async.until testFunction, checkFunction, (err)=>
          return done(err) if err
          @fakeConnection.trigger('endOfCandidates', 'some fake candidate')

      it 'fetches the nearest server', ->
        expect(@jsonpStub.calledOnce).to.be.true

      it 'triggers auth on the connection', ->
        expect(@primusStub.write.calledTwice).to.be.true
        args = @primusStub.write.firstCall.args
        expect(args).to.have.length(1)
        expect(args[0].action).to.equal('auth')
        expect(args[0].publicKey).to.equal("project-public-key")

      it 'adds the media stream to the peer connection', ->
        expect(@fakeConnection.streams).to.deep.equal([@mediaStream])

      it 'creates an offer to the broadcast bridge server', ->
        expect(@fakeConnection.offer.calledOnce).to.be.true

      it 'sends the broadcast-start action', ->
        expect(@primusStub.write.calledTwice).to.be.true
        args = @primusStub.write.secondCall.args
        expect(args).to.have.length(1)
        expect(args[0].streamType).to.equal('camera')
        expect(args[0].action).to.equal('broadcast-start')
        expect(args[0].offer).to.equal('full local description')
        expect(args[0].streamId).to.equal('the stream id')
        expect(args[0].streamKey).to.equal('the stream key')

      it 'consumes an answer from the broadcast bridge server', ->
        @subject.connection.primus.trigger('data', action: 'rtc-answer', streamType: 'camera', answer: 'the hello answer')
        expect(@fakeConnection.handleAnswer.calledOnce).to.be.true
        expect(@fakeConnection.handleAnswer.firstCall.args[0]).to.equal('the hello answer')

    describe '#stopBroadcast', ->
      it 'does nothing when there is no connection', (done)->
        @subject.stopBroadcast 'camera', (err)->
          expect(err).to.be.undefined
          done()

      describe 'with an open connection', ->
        beforeEach ->
          CineIOPeer.trigger('gotIceServers', some: 'ice data')

        beforeEach (done)->
          streamType = 'camera'
          @mediaStream = new FakeMediaStream
          streamId = 'the stream id'
          streamKey = 'the stream key'
          @subject.startBroadcast streamType, @mediaStream, streamId, streamKey, done

          fakeConnectionMade = false
          testFunction = -> fakeConnectionMade
          checkFunction = (callback)=>
            if @fakeConnection && @fakeConnection.offered
              @subject.connection.primus.trigger 'open'
              fakeConnectionMade = true
            setTimeout(callback, 10)
          async.until testFunction, checkFunction, (err)=>
            return done(err) if err
            @fakeConnection.trigger('endOfCandidates', 'some fake candidate')

        it 'does not error when when there is no stream for that type', (done)->
          @subject.stopBroadcast 'camera', (err)=>
            expect(err).to.be.undefined
            expect(@fakeConnection.close.calledOnce).to.be.true
            done()

        describe 'without a stream for that type', ->

          it 'closes the peer connection', (done)->
            @subject.stopBroadcast 'screen', (err)=>
              expect(err).to.be.undefined
              expect(@fakeConnection.close.calledOnce).to.be.false
              done()

          it 'tells the broadcast bridge', (done)->
            @subject.stopBroadcast 'screen', (err)=>
              expect(@primusStub.write.calledThrice).to.be.true
              expect(err).to.be.undefined
              args = @primusStub.write.thirdCall.args
              expect(args).to.have.length(1)
              expect(args[0].streamType).to.equal('screen')
              expect(args[0].action).to.equal('broadcast-stop')
              done()

        describe 'with a stream for that type', ->

          it 'closes the peer connection', (done)->
            @subject.stopBroadcast 'camera', (err)=>
              expect(err).to.be.undefined
              expect(@fakeConnection.close.calledOnce).to.be.true
              done()

          it 'tells the broadcast bridge', (done)->
            @subject.stopBroadcast 'camera', (err)=>
              expect(@primusStub.write.calledThrice).to.be.true
              expect(err).to.be.undefined
              args = @primusStub.write.thirdCall.args
              expect(args).to.have.length(1)
              expect(args[0].streamType).to.equal('camera')
              expect(args[0].action).to.equal('broadcast-stop')
              done()
