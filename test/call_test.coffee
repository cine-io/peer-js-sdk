setupAndTeardown = require('./helpers/setup_and_teardown')
CineIOPeer = require('../src/main')
Call = require('../src/call')
stubPrimus = require('./helpers/stub_primus')
stubUserMedia = require('./helpers/stub_user_media')

describe 'Call', ->
  setupAndTeardown()

  stubPrimus()

  stubUserMedia()

  beforeEach (done)->
    @dataTrigger = (data)->
      done()
    CineIOPeer.on 'info', @dataTrigger
    CineIOPeer.init(publicKey: 'the-public-key')

  afterEach ->
    CineIOPeer.off 'info', @dataTrigger

  beforeEach ->
    @call = new Call(room: 'Hogwarts Express')

  describe '#answer', ->
    it 'joins the room', (done)->
      @call.answer (err)=>
        expect(@primusStub.write.calledOnce).to.be.true
        args = @primusStub.write.firstCall.args
        expect(args).to.have.length
        expect(args[0]).to.deep.equal(action: 'join', room: 'Hogwarts Express', publicKey: 'the-public-key')
        done()

  describe '#reject', ->
    it 'sends a rejection', ->
      @call.reject()
      expect(@primusStub.write.calledOnce).to.be.true
      args = @primusStub.write.firstCall.args
      expect(args).to.have.length
      expect(args[0]).to.deep.equal(action: 'reject', room: 'Hogwarts Express', publicKey: 'the-public-key')
