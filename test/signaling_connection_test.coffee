setupAndTeardown = require('./helpers/setup_and_teardown')
CineIOPeer = require('../src/main')
SignalingConnection = require('../src/signaling_connection')
stubPrimus = require('./helpers/stub_primus')
FakePeerConnection = require('./helpers/fake_peer_connection')
async = require('async')

describe 'SignalingConnection', ->
  setupAndTeardown()
  stubPrimus()

  describe '.connect', ->
    it 'connects', ->
      connection = SignalingConnection.connect()
      expect(connection.primus).to.equal(@primusStub)

  describe 'connection actions', ->
    beforeEach ->
      @connection = SignalingConnection.connect()

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
      CineIOPeer.stream = "the stream"
      @connection.primus.trigger 'data', action: 'allservers', data: iceCandidates
      @connection.primus.trigger 'data', action: 'member', sparkId: sparkId
      addedStream = false
      testFunction = -> addedStream
      checkFunction = (callback)=>
        addedStream = true if @fakeConnection && @fakeConnection.stream == 'the stream'
        setTimeout(callback, 10)
      async.until testFunction, checkFunction, done

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
          CineIOPeer.off 'incomingcall', handler
          done()
        CineIOPeer.on 'incomingcall', handler
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
        CineIOPeer.stream = "the stream"
        @connection.primus.trigger 'data', action: 'allservers', data: 'the-ice-candidates-2'
        @connection.primus.trigger 'data', action: 'member', sparkId: 'some-spark-id-2'
        assertOffer.call this, "some-spark-id-2", (err)=>
          expect(@fakeConnection.stream).to.equal('the stream')
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

      it 'adds iceCandidate to the peer connection', ->
        @connection.primus.trigger 'data', action: 'ice', candidate: 'the-remote-ice-candidate', sparkId: 'some-spark-id-4'
        expect(@fakeConnection.remoteIce).to.equal('the-remote-ice-candidate')

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

      it 'handles the answer', ->
        @connection.primus.trigger 'data', action: 'answer', answer: 'the remote answer', sparkId: 'some-spark-id-5'
        expect(@fakeConnection.remoteAnswer).to.equal('the remote answer')

    describe 'other actions', ->
      it 'does not throw an exception', ->
        @connection.primus.trigger('data', action: 'UNKNOWN_ACTION')
  describe 'peer connection events'
  describe '#write', ->
    it 'is tested'
  describe '#newLocalStream', ->
    it 'is tested'
