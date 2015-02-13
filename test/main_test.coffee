setupAndTeardown = require('./helpers/setup_and_teardown')
CineIOPeer = require('../src/main')
CallObject = require('../src/call')
stubPrimus = require('./helpers/stub_primus')
stubUserMedia = require('./helpers/stub_user_media')
inPhantom = typeof window.URL == 'undefined'

describe 'CineIOPeer', ->
  setupAndTeardown()
  stubPrimus()

  describe '.version', ->
    it 'has a version', ->
      expect(CineIOPeer.version).to.equal('0.0.5')

  describe '.reset', ->
    it 'resets the config', ->
      CineIOPeer.config = {some: 'random', config: 'setting'}
      CineIOPeer.reset()
      expect(CineIOPeer.config).to.deep.equal(rooms: [], videoElements: {})

  describe '.init', ->

    setupDataTrigger = (cb)->
      @dataTrigger = cb
      CineIOPeer.on 'info', @dataTrigger
      CineIOPeer.on 'error', @dataTrigger

    afterEach ->
      CineIOPeer.off 'info', @dataTrigger
      CineIOPeer.off 'error', @dataTrigger

    it 'initializes the config', (done)->
      setupDataTrigger.call this, ->
        done()
      CineIOPeer.init('my-public-key')
      expect(CineIOPeer.config).to.deep.equal(publicKey: 'my-public-key', rooms: [], videoElements: {})

    it 'checks for support', (done)->
      setupDataTrigger.call this, (data)->
        expect(data).to.deep.equal(support: !inPhantom)
        done()
      CineIOPeer.init('my-public-key')

  describe 'after initialized', ->

    beforeEach (done)->
      @dataTrigger = (data)->
        done()
      CineIOPeer.on 'info', @dataTrigger
      CineIOPeer.on 'error', @dataTrigger
      CineIOPeer.init('the-public-key')

    afterEach ->
      CineIOPeer.off 'info', @dataTrigger
      CineIOPeer.off 'error', @dataTrigger

    describe '.identify', ->
      it 'sets an identity', ->
        CineIOPeer.identify('Minerva McGonagall', 'timely-timestamp', 'secure-signature')
        expect(CineIOPeer.config.identity.identity).to.equal('Minerva McGonagall')

      it 'writes to the signaling connection', ->
        CineIOPeer.identify('Minerva McGonagall', 'timely-timestamp', 'secure-signature')
        expect(@primusStub.write.calledOnce).to.be.true
        args = @primusStub.write.firstCall.args
        expect(args).to.have.length(1)
        expect(args[0].action).to.equal('identify')
        expect(args[0].identity).to.equal('Minerva McGonagall')
        expect(args[0].timestamp).to.equal('timely-timestamp')
        expect(args[0].signature).to.equal('secure-signature')
        expect(args[0].publicKey).to.equal('the-public-key')

    describe '.call', ->
      stubUserMedia()

      beforeEach ->
        CineIOPeer.identify('Minerva McGonagall')

      it 'writes to the signaling connection', (done)->
        CineIOPeer.call "Albus Dumbledore", (err, data)=>
          expect(err).to.be.null
          expect(@primusStub.write.calledTwice).to.be.true
          args = @primusStub.write.secondCall.args
          expect(args).to.have.length(1)
          expect(args[0].action).to.equal('call')
          expect(args[0].otheridentity).to.equal('Albus Dumbledore')
          expect(args[0].identity).to.equal('Minerva McGonagall')
          expect(args[0].publicKey).to.equal('the-public-key')
          done()
        callPlaced =
           action: 'ack'
           source: 'call'
           room: 'some-room-returned-by-the-server'
           otheridentity: 'Albus Dumbledore'
        CineIOPeer._signalConnection.primus.trigger 'data', callPlaced

      it 'returns a call object', (done)->
        CineIOPeer.call "Albus Dumbledore", (err, data)->
          expect(err).to.be.null
          expect(data.call.room).to.equal('some-room-returned-by-the-server')
          expect(data.call instanceof CallObject)
          done()
        callPlaced =
           action: 'ack'
           source: 'call'
           room: 'some-room-returned-by-the-server'
           otheridentity: 'Albus Dumbledore'
        CineIOPeer._signalConnection.primus.trigger 'data', callPlaced

      it 'takes a room', (done)->
        CineIOPeer.call "Albus Dumbledore", 'some-room', (err)=>
          expect(err).to.be.null
          expect(@primusStub.write.calledTwice).to.be.true
          args = @primusStub.write.secondCall.args
          expect(args).to.have.length(1)
          expect(args[0].action).to.equal('call')
          expect(args[0].otheridentity).to.equal('Albus Dumbledore')
          expect(args[0].identity).to.equal('Minerva McGonagall')
          expect(args[0].publicKey).to.equal('the-public-key')
          done()
        callPlaced =
           action: 'ack'
           source: 'call'
           room: 'some-room'
           otheridentity: 'Albus Dumbledore'
        CineIOPeer._signalConnection.primus.trigger 'data', callPlaced


    describe '.join', ->
      stubUserMedia()

      it 'adds the room to the list of rooms', (done)->
        CineIOPeer.join "Gryffindor Common Room", (err)->
          expect(err).to.be.undefined
          expect(CineIOPeer.config.rooms).to.deep.equal(['Gryffindor Common Room'])
          done()

      it 'writes to the signaling connection', (done)->
        CineIOPeer.join "Gryffindor Common Room", (err)=>
          expect(err).to.be.undefined
          expect(@primusStub.write.calledOnce).to.be.true
          args = @primusStub.write.firstCall.args
          expect(args).to.have.length(1)
          expect(args[0].action).to.equal('room-join')
          expect(args[0].room).to.equal('Gryffindor Common Room')
          expect(args[0].publicKey).to.equal('the-public-key')
          done()

    describe '.leave', ->
      stubUserMedia()

      it 'requires the user have previously joined the room', (done)->
        errorHandler = (data)->
          expect(data).to.deep.equal(msg: "not connected to room", room: "Gryffindor Common Room")
          CineIOPeer.off 'error', errorHandler
          done()
        CineIOPeer.on 'error', errorHandler
        CineIOPeer.leave "Gryffindor Common Room"

      it 'removes the room to the list of rooms', (done)->
        CineIOPeer.join "Gryffindor Common Room", (err)->
          expect(err).to.be.undefined
          expect(CineIOPeer.config.rooms).to.contain("Gryffindor Common Room")
          CineIOPeer.leave("Gryffindor Common Room")
          expect(CineIOPeer.config.rooms).not.to.contain("Gryffindor Common Room")
          done()

      it 'writes to the signaling connection', (done)->
        CineIOPeer.join "Gryffindor Common Room", (err)=>
          expect(err).to.be.undefined
          CineIOPeer.leave("Gryffindor Common Room")
          expect(@primusStub.write.calledTwice).to.be.true
          args = @primusStub.write.secondCall.args
          expect(args).to.have.length(1)
          expect(args[0].action).to.equal('room-leave')
          expect(args[0].room).to.equal('Gryffindor Common Room')
          expect(args[0].publicKey).to.equal('the-public-key')
          done()

    describe '.startCameraAndMicrophone', ->
      describe 'success', ->
        stubUserMedia()

        it 'fetches media', (done)->
          CineIOPeer.startCameraAndMicrophone (err)->
            expect(err).to.be.undefined
            expect(CineIOPeer._unsafeGetUserMedia.calledOnce).to.be.true
            args = CineIOPeer._unsafeGetUserMedia.firstCall.args
            expect(args).to.have.length(2)
            expect(args[0]).to.deep.equal(audio: true, video: true)
            expect(args[1]).to.be.a('function')
            done()

        it 'will not fetch twice', (done)->
          CineIOPeer.startCameraAndMicrophone (err)->
            expect(err).to.be.undefined
            CineIOPeer.startCameraAndMicrophone (err)->
              expect(err).to.be.undefined
              expect(CineIOPeer._unsafeGetUserMedia.calledOnce).to.be.true
              args = CineIOPeer._unsafeGetUserMedia.firstCall.args
              expect(args).to.have.length(2)
              expect(args[0]).to.deep.equal(audio: true, video: true)
              expect(args[1]).to.be.a('function')
              done()

        it 'triggers media with the stream and media true', (done)->
          mediaResponse = (data)->
            expect(data.local).to.be.true
            expect(data.videoElement.tagName).to.equal('VIDEO')
            expect(data.videoElement.src).to.equal("blob:http%3A//#{window.location.host}/identifier")
            expect(data.stream.id).to.equal('stream-id')
            CineIOPeer.off 'media-added', mediaResponse
            done()
          CineIOPeer.on 'media-added', mediaResponse
          CineIOPeer.startCameraAndMicrophone()

      describe 'failure', ->
        stubUserMedia(false)

        it 'returns with the error', (done)->
          mediaResponse = (data)->
            CineIOPeer.off 'media-rejected', mediaResponse
            done()
          CineIOPeer.on 'media-rejected', mediaResponse
          CineIOPeer.startCameraAndMicrophone (err)->
            expect(err).to.equal('could not fetch media')

        it 'triggers media with the stream and media false', (done)->
          mediaResponse = (data)->
            expect(data.local).to.be.true
            expect(data.videoElement).to.be.undefined
            expect(data.stream).to.be.undefined

            CineIOPeer.off 'media-rejected', mediaResponse
            done()
          CineIOPeer.on 'media-rejected', mediaResponse
          CineIOPeer.startCameraAndMicrophone()
