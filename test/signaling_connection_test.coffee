setupAndTeardown = require('./helpers/setup_and_teardown')
CineIOPeer = require('../src/main')
SignalingConnection = require('../src/signaling_connection')
PeerConnectionFactory = require('../src/peer_connection_factory')
stubPrimus = require('./helpers/stub_primus')
FakePeerConnection = require('./helpers/fake_peer_connection')
FakeMediaStream = require('./helpers/fake_media_stream')
async = require('async')
stubCreateObjectUrl = require("./helpers/stub_create_object_url")
debug = require('../src/debug')('cine:peer:signaling_connection_test')

describe 'SignalingConnection', ->
  setupAndTeardown()
  stubPrimus()

  beforeEach ->
    CineIOPeer.config.publicKey = 'project-public-key'

  beforeEach ->
    @connection = SignalingConnection.connect()

  beforeEach ->
    sinon.stub PeerConnectionFactory, 'create', =>
      if @fakeConnection
        debug("ugh fakeConnection")
        throw new Error("Two connections made!!!")
      @fakeConnection = new FakePeerConnection()

  afterEach ->
    PeerConnectionFactory.create.restore()

  afterEach ->
    if @fakeConnection
      debug("deleting fakeConnection")
      delete @fakeConnection

  createNewPeer = (sparkId, iceCandidates, done)->
    CineIOPeer.cameraStream = "the stream"
    @connection.primus.trigger 'data', action: 'rtc-servers', data: iceCandidates
    @connection.primus.trigger 'data', action: 'room-join', sparkId: sparkId, sparkUUID: "#{sparkId}-uuid"
    addedStream = false
    testFunction = -> addedStream
    checkFunction = (callback)=>
      addedStream = true if @fakeConnection && @fakeConnection.streams[0] == 'the stream'
      setTimeout(callback, 10)
    async.until testFunction, checkFunction, done

  describe '.connect', ->
    it 'connects', ->
      expect(@connection.primus).to.equal(@primusStub)

    it 'has a uuid', ->
      expect(@connection.myUUID).to.have.length(36)

    it 'triggers auth on the connection', ->
      @connection.primus.trigger 'open'
      @primusStub.write.calledOnce
      args = @primusStub.write.firstCall.args
      expect(args).to.have.length(1)
      expect(args[0].action).to.equal('auth')
      expect(args[0].publicKey).to.equal("project-public-key")

  describe 'connection actions', ->
    describe 'error', ->
      it 'triggers an event', (done)->
        handler = (data)->
          CineIOPeer.off 'error', handler
          expect(data.data).to.equal('some error data')
          done()
        CineIOPeer.on 'error', handler
        @connection.primus.trigger 'data', action: 'error', data: "some error data"

    describe "rtc-servers", ->

      it 'writes the ice servers', ->
        @connection.primus.trigger 'data', action: 'rtc-servers', data: "some ice servers"
        expect(@connection.iceServers).to.equal("some ice servers")

      it 'goes from not having fetched ice servers to having fetched them', ->
        expect(@connection.fetchedIce).to.be.false
        @connection.primus.trigger 'data', action: 'rtc-servers', data: "some ice servers"
        expect(@connection.fetchedIce).to.be.true

      it 'triggers an event', (done)->
        handler = (data)->
          CineIOPeer.off 'gotIceServers', handler
          expect(data).to.equal('some ice servers')
          done()
        CineIOPeer.on 'gotIceServers', handler
        @connection.primus.trigger 'data', action: 'rtc-servers', data: "some ice servers"

    describe "call", ->

      it 'triggers an event', (done)->
        handler = (data)->
          expect(data.call.answer).to.be.a('function')
          expect(data.call.reject).to.be.a('function')
          expect(data.call.room).to.equal('some-room')
          CineIOPeer.off 'call', handler
          done()
        CineIOPeer.on 'call', handler
        @connection.primus.trigger 'data', action: 'call', room: 'some-room'

    describe "room-leave", ->
      it 'closes the connection for that peer', ->
        pc = new FakePeerConnection
        @connection.peerConnections['some-spark-uuid'] = pc
        @connection.primus.trigger 'data', action: 'room-leave', sparkId: 'some-spark-id', sparkUUID: 'some-spark-uuid'
        expect(pc.close.calledOnce).to.be.true
        expect(@connection.peerConnections).to.deep.equal({})

      it 'does nothing when the peer is not available', ->
        pc = new FakePeerConnection
        @connection.peerConnections['some-second-spark-uuid'] = pc
        @connection.primus.trigger 'data', action: 'room-leave', sparkId: 'some-spark-id', sparkUUID: 'some-spark-uuid'
        expect(pc.close.calledOnce).to.be.false
        expect(@connection.peerConnections).to.deep.equal('some-second-spark-uuid': pc)

    describe "room-join", ->
      assertOffer = (sparkId, done)->
        wroteOffer = false
        testFunction = -> wroteOffer
        checkFunction = (callback)=>
          if @primusStub.write.calledTwice
            args = @primusStub.write.secondCall.args
            expect(args).to.have.length(1)
            expect(args[0].action).to.equal('rtc-offer')
            expect(args[0].offer).to.equal('some-offer-string')
            expect(args[0].sparkId).to.equal(sparkId)
            wroteOffer = true
          setTimeout(callback, 10)
        async.until testFunction, checkFunction, done

      it 'does not send an offer without a stream', (done)->
        CineIOPeer.once 'peerConnectionMade', =>
          expect(@primusStub.write.calledOnce).to.be.true
          done()
        @connection.primus.trigger 'data', action: 'rtc-servers', data: 'the-ice-candidates-1'
        @connection.primus.trigger 'data', action: 'room-join', sparkId: 'some-spark-id', sparkUUID: "some-spark-uuid"

      it 'sends an announcement', (done)->
        CineIOPeer.once 'peerConnectionMade', done
        @connection.primus.trigger 'data', action: 'rtc-servers', data: 'the-ice-candidates-1'
        @connection.primus.trigger 'data', action: 'room-join', sparkId: 'some-spark-id', sparkUUID: "some-spark-uuid"
        expect(@primusStub.write.calledOnce).to.be.true
        args = @primusStub.write.firstCall.args
        expect(args).to.have.length(1)
        expect(args[0].action).to.equal('room-announce')
        expect(args[0].sparkId).to.equal('some-spark-id')
        expect(args[0].uuid).to.be.ok
        expect(args[0].uuid).to.equal(@connection.myUUID)

      it 'attaches the cineio stream', (done)->
        CineIOPeer.cameraStream = "the stream"
        @connection.primus.trigger 'data', action: 'rtc-servers', data: 'the-ice-candidates-2'
        @connection.primus.trigger 'data', action: 'room-join', sparkId: 'some-spark-id-2', sparkUUID: 'some-spark-uuid-2'
        assertOffer.call this, "some-spark-id-2", (err)=>
          expect(@fakeConnection.streams).to.deep.equal(['the stream'])
          done(err)

      it 'waits for ice candidates', (done)->
        CineIOPeer.cameraStream = "the stream"
        @connection.primus.trigger 'data', action: 'room-join', sparkId: 'some-spark-id-3'
        setTimeout =>
          @connection.primus.trigger 'data', action: 'rtc-servers', data: 'the-ice-candidates-3'
          assertOffer.call(this, "some-spark-id-3", done)

    describe "room-announce", ->
      it 'makes a peer connection without making an offer', (done)->
        CineIOPeer.once 'peerConnectionMade', done
        @connection.primus.trigger 'data', action: 'rtc-servers', data: 'the-ice-candidates-2'
        @connection.primus.trigger 'data', action: 'room-announce', sparkId: 'some-spark-id-3'

    describe "rtc-ice", ->
      beforeEach (done)->
        createNewPeer.call(this, 'some-spark-id-4', 'the-ice-candidates-4', done)

      it 'does not error without a spark id', ->
        @connection.primus.trigger 'data', action: 'rtc-ice', candidate: 'the-remote-ice-candidate'
        expect(@fakeConnection.remoteIce).to.be.undefined

      it 'does not send an offer when creating a new peer client'

      it 'adds iceCandidate to the peer connection', (done)->
        @connection.primus.trigger 'data', action: 'rtc-ice', candidate: 'the-remote-ice-candidate', sparkId: 'some-spark-id-4', sparkUUID: 'some-spark-id-4-uuid'
        hasIce = false
        testFunction = -> hasIce
        checkFunction = (callback)=>
          hasIce = @fakeConnection.remoteIce == 'the-remote-ice-candidate'
          setTimeout(callback, 10)
        async.until testFunction, checkFunction, done

    describe "rtc-offer", ->
      beforeEach (done)->
        createNewPeer.call(this, 'some-spark-id-5', 'the-ice-candidates-5', done)

      assertAnswer = (sparkId, done)->
        wroteOffer = false
        testFunction = -> wroteOffer
        checkFunction = (callback)=>
          if @primusStub.write.calledThrice
            args = @primusStub.write.thirdCall.args
            expect(args).to.have.length(1)
            expect(args[0].action).to.equal('rtc-answer')
            expect(args[0].answer).to.equal('some-answer-string')
            expect(args[0].sparkId).to.equal(sparkId)
            wroteOffer = true
          setTimeout(callback, 10)
        async.until testFunction, checkFunction, done

      it 'handles the offer', (done)->
        @connection.primus.trigger 'data', action: 'rtc-offer', offer: 'the remote offer', sparkId: 'some-spark-id-5', sparkUUID: 'some-spark-id-5-uuid'
        assertAnswer.call this, 'some-spark-id-5', (err)=>
          expect(@fakeConnection.remoteOffer).to.equal('the remote offer')
          done(err)

      it 'returns an answer', (done)->
        @connection.primus.trigger 'data', action: 'rtc-offer', offer: 'the remote offer', sparkId: 'some-spark-id-5', sparkUUID: 'some-spark-id-5-uuid'
        assertAnswer.call this, 'some-spark-id-5', (err)=>
          expect(@fakeConnection.answer.calledOnce).to.be.true
          done(err)

    describe "rtc-answer", ->
      beforeEach (done)->
        createNewPeer.call(this, 'some-spark-id-5', 'the-ice-candidates-5', done)

      it 'handles the answer', (done)->
        @connection.primus.trigger 'data', action: 'rtc-answer', answer: 'the remote answer', sparkId: 'some-spark-id-5', sparkUUID: 'some-spark-id-5-uuid'
        hasAnswer = false
        testFunction = -> hasAnswer
        checkFunction = (callback)=>
          hasAnswer = @fakeConnection.remoteAnswer == 'the remote answer'
          setTimeout(callback, 10)
        async.until testFunction, checkFunction, done

    describe 'other actions', ->
      it 'does not throw an exception', ->
        @connection.primus.trigger('data', action: 'UNKNOWN_ACTION')

  describe 'peer connection events', ->
    beforeEach (done)->
      createNewPeer.call(this, 'some-spark-id-8', 'the-ice-candidates-5', done)

    describe 'addStream', ->
      stubCreateObjectUrl("unique-identifier")
      it 'adds the video element to the peer connection', ->
        @fakeConnection.trigger 'addStream', stream: new FakeMediaStream
        expect(@fakeConnection.videoEls).to.have.length(1)
        video = @fakeConnection.videoEls[0]
        expect(video.tagName).to.equal("VIDEO")
        expect(video.src).to.equal("blob:http%3A//#{window.location.host}/unique-identifier")

      it 'triggers streamAdded', (done)->
        handler = (data)=>
          CineIOPeer.off 'media-added', handler
          expect(data.peerConnection).to.equal(@fakeConnection)
          expect(data.videoElement).to.equal(@fakeConnection.videoEls[0])
          expect(data.remote).to.be.true
          done()
        CineIOPeer.on 'media-added', handler
        @fakeConnection.trigger 'addStream', stream: new FakeMediaStream

    describe 'removeStream', ->
      stubCreateObjectUrl("second-unique-identifier")
      beforeEach ->
        @mediaStream = new FakeMediaStream
        @fakeConnection.trigger 'addStream', stream: @mediaStream
        expect(@fakeConnection.videoEls).to.have.length(1)

      it 'removes the video element from the peer connection', ->
        @fakeConnection.trigger 'removeStream', stream: @mediaStream
        expect(@fakeConnection.videoEls).to.have.length(0)

      it 'triggers streamRemoved', (done)->
        videoElement = @fakeConnection.videoEls[0]
        handler = (data)=>
          CineIOPeer.off 'media-removed', handler
          expect(data.peerConnection).to.equal(@fakeConnection)
          expect(data.videoElement).to.equal(videoElement)
          expect(data.remote).to.be.true
          done()
        CineIOPeer.on 'media-removed', handler
        @fakeConnection.trigger 'removeStream', stream: new FakeMediaStream

    describe 'ice', ->
      it 'writes to primus', ->
        @fakeConnection.trigger 'ice', 'some candidate'
        expect(@primusStub.write.calledThrice).to.be.true
        args = @primusStub.write.thirdCall.args
        expect(args).to.have.length(1)
        expect(args[0].action).to.equal('rtc-ice')
        expect(args[0].candidate).to.equal("some candidate")
        expect(args[0].sparkId).to.equal('some-spark-id-8')

    describe 'close', ->
      stubCreateObjectUrl("third-unique-identifier")
      beforeEach ->
        @mediaStream1 = new FakeMediaStream
        @fakeConnection.trigger 'addStream', stream: @mediaStream1
        @mediaStream2 = new FakeMediaStream
        @fakeConnection.trigger 'addStream', stream: @mediaStream2
        expect(@fakeConnection.videoEls).to.have.length(2)

      it 'triggers media-removed for all videos', (done)->
        callCount = 0
        firstVideoIndex = null
        videos = @fakeConnection.videoEls
        handler = (data)=>
          callCount +=1
          expect(data.peerConnection).to.equal(@fakeConnection)
          expect(data.remote).to.be.true
          index = videos.indexOf(data.videoElement)
          expect(index).to.be.gte(0)
          return firstVideoIndex = index if callCount == 1
          expect(firstVideoIndex).not.to.equal(index)
          CineIOPeer.off 'media-removed', handler
          done()

        CineIOPeer.on 'media-removed', handler
        @fakeConnection.trigger 'close'


  describe '#write', ->
    it 'calls to primus', ->
      @connection.write some: 'data'
      expect(@primusStub.write.calledOnce).to.be.true
      args = @primusStub.write.firstCall.args
      expect(args).to.have.length(1)
      expect(args[0].some).to.equal('data')
      expect(args[0].client).to.equal("cineio-peer-js version-#{CineIOPeer.version}")
      expect(args[0].publicKey).to.equal('project-public-key')
      expect(args[0].uuid).to.have.length(36)

  describe '#addLocalStream', ->
    beforeEach ->
      @connection.peerConnections['a'] = new FakePeerConnection
      @connection.peerConnections['a'].addStream('first stream')
      @connection.peerConnections['b'] = new FakePeerConnection
      @connection.peerConnections['b'].addStream('first stream')

    it 'adds the stream to all the connections', ->
      @connection.addLocalStream('my new stream')
      expect(@connection.peerConnections['a'].streams).to.have.length(2)
      expect(@connection.peerConnections['a'].streams).to.deep.equal(['first stream', 'my new stream'])
      expect(@connection.peerConnections['b'].streams).to.have.length(2)
      expect(@connection.peerConnections['b'].streams).to.deep.equal(['first stream', 'my new stream'])

    it 'resends the offer', ->
      @connection.addLocalStream('my new stream')
      expect(@connection.peerConnections['a'].offer.calledOnce).to.be.true
      expect(@connection.peerConnections['b'].offer.calledOnce).to.be.true

    it "won't resend the offer when silent the offer", ->
      @connection.addLocalStream('my new stream', silent: true)
      expect(@connection.peerConnections['a'].offer.called).to.be.false
      expect(@connection.peerConnections['b'].offer.called).to.be.false

  describe '#removeLocalStream', ->
    beforeEach ->
      @connection.peerConnections['a'] = new FakePeerConnection
      @connection.peerConnections['a'].addStream('first stream')
      @connection.peerConnections['b'] = new FakePeerConnection
      @connection.peerConnections['b'].addStream('first stream')

    it 'removes the stream from all the connections', ->
      @connection.removeLocalStream('first stream')
      expect(@connection.peerConnections['a'].streams).to.have.length(0)
      expect(@connection.peerConnections['b'].streams).to.have.length(0)

    it 'resends the offer', ->
      @connection.removeLocalStream('first stream')
      expect(@connection.peerConnections['a'].offer.calledOnce).to.be.true
      expect(@connection.peerConnections['b'].offer.calledOnce).to.be.true

    it "won't resend the offer when silent the offer", ->
      @connection.removeLocalStream('first stream', silent: true)
      expect(@connection.peerConnections['a'].offer.called).to.be.false
      expect(@connection.peerConnections['b'].offer.called).to.be.false
