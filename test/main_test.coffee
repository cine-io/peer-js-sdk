CineIOPeer = require('../src/main')
stubPrimus = require('./helpers/stub_primus')
stubUserMedia = require('./helpers/stub_user_media')
describe 'CineIOPeer', ->

  beforeEach ->
    CineIOPeer.reset()

  afterEach ->
    delete CineIOPeer._signalConnection

  stubPrimus()

  describe '.version', ->
    it 'has a version', ->
      expect(CineIOPeer.version).to.equal('0.0.1')

  describe '.reset', ->
    it 'resets the config', ->
      CineIOPeer.config = {some: 'random', config: 'setting'}
      CineIOPeer.reset()
      expect(CineIOPeer.config).to.deep.equal(rooms: [], videoElements: {})

  describe '.init', ->

    setupDataTrigger = (cb)->
      @dataTrigger = cb
      CineIOPeer.on 'info', @dataTrigger

    afterEach ->
      CineIOPeer.off 'info', @dataTrigger

    it 'initializes the config', (done)->
      setupDataTrigger.call this, ->
        done()
      CineIOPeer.init(publicKey: 'my-public-key')
      expect(CineIOPeer.config).to.deep.equal(publicKey: 'my-public-key', rooms: [], videoElements: {})

    it 'checks for support', (done)->
      setupDataTrigger.call this, (data)->
        expect(data).to.deep.equal(support: true)
        done()
      CineIOPeer.init(publicKey: 'my-public-key')

  describe 'after initialized', ->

    beforeEach (done)->
      @dataTrigger = (data)->
        done()
      CineIOPeer.on 'info', @dataTrigger
      CineIOPeer.init(publicKey: 'the-public-key')

    afterEach ->
      CineIOPeer.off 'info', @dataTrigger

    describe '.identify', ->
      it 'sets an identity', ->
        CineIOPeer.identify('Minerva McGonagall')
        expect(CineIOPeer.config.identity).to.equal('Minerva McGonagall')

      it 'writes to the signaling connection', ->
        CineIOPeer.identify('Minerva McGonagall')
        expect(@primusStub.write.calledOnce).to.be.true
        args = @primusStub.write.firstCall.args
        expect(args).to.have.length
        expect(args[0]).to.deep.equal(action: 'identify', identity: 'Minerva McGonagall', publicKey: 'the-public-key', client: 'web')

    describe '.call', ->
      stubUserMedia()

      beforeEach ->
        CineIOPeer.identify('Minerva McGonagall')

      it 'fetches media', (done)->
        CineIOPeer.call "Albus Dumbledore", (err)->
          expect(err).to.be.undefined
          expect(CineIOPeer._unsafeGetUserMedia.calledOnce).to.be.true
          args = CineIOPeer._unsafeGetUserMedia.firstCall.args
          expect(args).to.have.length(2)
          expect(args[0]).to.deep.equal(audio: true, video: true)
          expect(args[1]).to.be.a('function')
          done()

      it 'writes to the signaling connection', (done)->
        CineIOPeer.call "Albus Dumbledore", (err)=>
          expect(err).to.be.undefined
          expect(@primusStub.write.calledTwice).to.be.true
          args = @primusStub.write.secondCall.args
          expect(args).to.have.length
          expect(args[0]).to.deep.equal(action: 'call', otheridentity: 'Albus Dumbledore', identity: 'Minerva McGonagall', publicKey: 'the-public-key')
          done()
