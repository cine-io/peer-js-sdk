CineIOPeer = require('../src/main')
stubPrimus = require('./helpers/stub_primus')
describe 'CineIOPeer', ->

  beforeEach ->
    CineIOPeer.reset()

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

    it 'initializes the  the config', (done)->
      setupDataTrigger.call this, ->
        done()
      CineIOPeer.init(publicKey: 'my-public-key')
      expect(CineIOPeer.config).to.deep.equal(publicKey: 'my-public-key', rooms: [], videoElements: {})

    it 'checks for support', (done)->
      setupDataTrigger.call this, (data)->
        expect(data).to.deep.equal(support: true)
        done()
      CineIOPeer.init(publicKey: 'my-public-key')
