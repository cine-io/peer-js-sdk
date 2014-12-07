setupAndTeardown = require('./helpers/setup_and_teardown')
CineIOPeer = require('../src/main')
SignalingConnection = require('../src/signaling_connection')
stubPrimus = require('./helpers/stub_primus')
FakePeerConnection = require('./helpers/fake_peer_connection')
FakeMediaStream = require('./helpers/fake_media_stream')
async = require('async')
stubCreateObjectUrl = require("./helpers/stub_create_object_url")

describe 'SignalingConnection', ->
  setupAndTeardown()
  stubPrimus()

  beforeEach ->
    @connection = SignalingConnection.connect(publicKey: 'project-public-key')

  beforeEach ->
    sinon.stub @connection, '_initializeNewPeerConnection', (options)=>
      if @fakeConnection
        console.log("ugh fakeConnection", options.sparkId, @fakeConnection.options.sparkId)
        throw new Error("Two connections made!!!")
      @fakeConnection = new FakePeerConnection(options)

  afterEach ->
    if @fakeConnection
      console.log("deleting fakeConnection", @fakeConnection.options.sparkId)
      delete @fakeConnection

  createNewPeer = (sparkId, iceCandidates, done)->
    CineIOPeer.cameraStream = "the stream"
    @connection.primus.trigger 'data', action: 'allservers', data: iceCandidates
    @connection.primus.trigger 'data', action: 'member', sparkId: sparkId
    addedStream = false
    testFunction = -> addedStream
    checkFunction = (callback)=>
      addedStream = true if @fakeConnection && @fakeConnection.streams[0] == 'the stream'
      setTimeout(callback, 10)
    async.until testFunction, checkFunction, done

  describe '.connect', ->
    it 'connects', ->
      expect(@connection.primus).to.equal(@primusStub)

    it 'passes options', ->
      expect(@connection.options).to.deep.equal('project-public-key')

    it 'triggers auth on the connection', ->
      @connection.primus.trigger 'open'
      @primusStub.write.calledOnce
      args = @primusStub.write.firstCall.args
      expect(args).to.have.length(1)
      expect(args[0]).to.deep.equal(action: 'auth', publicKey: "project-public-key")

  describe 'connection actions', ->

    describe "allservers", ->

      it 'writes the ice servers', ->
        @connection.primus.trigger 'data', action: 'allservers', data: "some ice servers"
        expect(@connection.iceServers).to.equal("some ice servers")

      it 'goes from not having fetched ice servers to having fetched them', ->
        expect(@connection.fetchedIce).to.be.false
        @connection.primus.trigger 'data', action: 'allservers', data: "some ice servers"
        expect(@connection.fetchedIce).to.be.true

      it 'triggers an event', (done)->
        handler = ->
          CineIOPeer.off 'gotIceServers', handler
          done()
        CineIOPeer.on 'gotIceServers', handler
        @connection.primus.trigger 'data', action: 'allservers', data: "some ice servers"

    describe "incomingcall", ->
      it 'triggers an event', (done)->
        handler = (data)->
          expect(data.call.answer).to.be.a('function')
          expect(data.call.reject).to.be.a('function')
          expect(data.call._data.room).to.equal('some-room')
          CineIOPeer.off 'incomingCall', handler
          done()
        CineIOPeer.on 'incomingCall', handler
        @connection.primus.trigger 'data', action: 'incomingcall', room: 'some-room'
    describe "leave", ->
      it 'closes the connection for that peer', ->
        pc = new FakePeerConnection
        @connection.peerConnections['some-spark-id'] = pc
        @connection.primus.trigger 'data', action: 'leave', sparkId: 'some-spark-id'
        expect(pc.close.calledOnce).to.be.true
        expect(@connection.peerConnections).to.deep.equal({})

      it 'does nothing when the peer is not available', ->
        pc = new FakePeerConnection
        @connection.peerConnections['some-second-spark-id'] = pc
        @connection.primus.trigger 'data', action: 'leave', sparkId: 'some-spark-id'
        expect(pc.close.calledOnce).to.be.false
        expect(@connection.peerConnections).to.deep.equal('some-second-spark-id': pc)

    describe "member", ->
      assertOffer = (sparkId, done)->
        wroteOffer = false
        testFunction = -> wroteOffer
        checkFunction = (callback)=>
          if @primusStub.write.calledOnce
            args = @primusStub.write.firstCall.args
            expect(args).to.have.length(1)
            expect(args[0]).to.deep.equal(action: 'offer', source: "web", offer: 'some-offer-string', sparkId: sparkId)
            wroteOffer = true
          setTimeout(callback, 10)
        async.until testFunction, checkFunction, done

      it 'sends an offer', (done)->
        @connection.primus.trigger 'data', action: 'allservers', data: 'the-ice-candidates-1'
        @connection.primus.trigger 'data', action: 'member', sparkId: 'some-spark-id'
        assertOffer.call(this, "some-spark-id", done)

      it 'attaches the cineio stream', (done)->
        CineIOPeer.cameraStream = "the stream"
        @connection.primus.trigger 'data', action: 'allservers', data: 'the-ice-candidates-2'
        @connection.primus.trigger 'data', action: 'member', sparkId: 'some-spark-id-2'
        assertOffer.call this, "some-spark-id-2", (err)=>
          expect(@fakeConnection.streams).to.deep.equal(['the stream'])
          done(err)

      it 'waits for ice candidates', (done)->
        @connection.primus.trigger 'data', action: 'member', sparkId: 'some-spark-id-3'
        setTimeout =>
          @connection.primus.trigger 'data', action: 'allservers', data: 'the-ice-candidates-3'
          assertOffer.call(this, "some-spark-id-3", done)

    describe "ice", ->
      beforeEach (done)->
        createNewPeer.call(this, 'some-spark-id-4', 'the-ice-candidates-4', done)

      it 'does not error without a spark id', ->
        @connection.primus.trigger 'data', action: 'ice', candidate: 'the-remote-ice-candidate'
        expect(@fakeConnection.remoteIce).to.be.undefined

      it 'does not send an offer when creating a new peer client'

      it 'adds iceCandidate to the peer connection', (done)->
        @connection.primus.trigger 'data', action: 'ice', candidate: 'the-remote-ice-candidate', sparkId: 'some-spark-id-4'
        hasIce = false
        testFunction = -> hasIce
        checkFunction = (callback)=>
          hasIce = @fakeConnection.remoteIce == 'the-remote-ice-candidate'
          setTimeout(callback, 10)
        async.until testFunction, checkFunction, done

    describe "offer", ->
      beforeEach (done)->
        createNewPeer.call(this, 'some-spark-id-5', 'the-ice-candidates-5', done)

      assertAnswer = (sparkId, done)->
        wroteOffer = false
        testFunction = -> wroteOffer
        checkFunction = (callback)=>
          if @primusStub.write.calledTwice
            args = @primusStub.write.secondCall.args
            expect(args).to.have.length(1)
            expect(args[0]).to.deep.equal(action: 'answer', source: "web", answer: 'some-answer-string', sparkId: sparkId)
            wroteOffer = true
          setTimeout(callback, 10)
        async.until testFunction, checkFunction, done

      it 'handles the offer', (done)->
        @connection.primus.trigger 'data', action: 'offer', offer: 'the remote offer', sparkId: 'some-spark-id-5'
        assertAnswer.call this, 'some-spark-id-5', (err)=>
          expect(@fakeConnection.remoteOffer).to.equal('the remote offer')
          done(err)

      it 'returns an answer', (done)->
        @connection.primus.trigger 'data', action: 'offer', offer: 'the remote offer', sparkId: 'some-spark-id-5'
        assertAnswer.call this, 'some-spark-id-5', (err)=>
          expect(@fakeConnection.answer.calledOnce).to.be.true
          done(err)

    describe "answer", ->
      beforeEach (done)->
        createNewPeer.call(this, 'some-spark-id-5', 'the-ice-candidates-5', done)

      it 'handles the answer', (done)->
        @connection.primus.trigger 'data', action: 'answer', answer: 'the remote answer', sparkId: 'some-spark-id-5'
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
          CineIOPeer.off 'mediaAdded', handler
          expect(data.peerConnection).to.equal(@fakeConnection)
          expect(data.videoElement).to.equal(@fakeConnection.videoEls[0])
          expect(data.remote).to.be.true
          done()
        CineIOPeer.on 'mediaAdded', handler
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
          CineIOPeer.off 'mediaRemoved', handler
          expect(data.peerConnection).to.equal(@fakeConnection)
          expect(data.videoElement).to.equal(videoElement)
          expect(data.remote).to.be.true
          done()
        CineIOPeer.on 'mediaRemoved', handler
        @fakeConnection.trigger 'removeStream', stream: new FakeMediaStream
    describe 'ice', ->
      it 'writes to primus', ->
        @fakeConnection.trigger 'ice', 'some candidate'
        expect(@primusStub.write.calledTwice).to.be.true
        args = @primusStub.write.secondCall.args
        expect(args).to.have.length(1)
        expect(args[0]).to.deep.equal(action: 'ice', source: 'web', candidate: "some candidate", sparkId: 'some-spark-id-8')

    describe 'close', ->
      stubCreateObjectUrl("third-unique-identifier")
      beforeEach ->
        @mediaStream1 = new FakeMediaStream
        @fakeConnection.trigger 'addStream', stream: @mediaStream1
        @mediaStream2 = new FakeMediaStream
        @fakeConnection.trigger 'addStream', stream: @mediaStream2
        expect(@fakeConnection.videoEls).to.have.length(2)

      it 'triggers mediaRemoved for all videos', (done)->
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
          CineIOPeer.off 'mediaRemoved', handler
          done()

        CineIOPeer.on 'mediaRemoved', handler
        @fakeConnection.trigger 'close'


  describe '#write', ->
    it 'calls to primus', ->
      @connection.write some: 'data'
      expect(@primusStub.write.calledOnce).to.be.true
      args = @primusStub.write.firstCall.args
      expect(args).to.have.length(1)
      expect(args[0]).to.deep.equal(some: 'data')

  describe '#newLocalStream', ->
    it 'adds the stream to all the', ->
      @connection.peerConnections['a'] = new FakePeerConnection
      @connection.peerConnections['a'].addStream('first stream')
      @connection.peerConnections['b'] = new FakePeerConnection
      @connection.peerConnections['b'].addStream('first stream')
      @connection.newLocalStream('my new stream')
      expect(@connection.peerConnections['a'].streams).to.have.length(2)
      expect(@connection.peerConnections['a'].streams).to.deep.equal(['first stream', 'my new stream'])
      expect(@connection.peerConnections['b'].streams).to.have.length(2)
      expect(@connection.peerConnections['b'].streams).to.deep.equal(['first stream', 'my new stream'])
