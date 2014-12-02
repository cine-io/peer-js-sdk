CineIOPeer = require('../src/main')
stubPrimus = require('./helpers/stub_primus')
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
