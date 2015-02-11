setupAndTeardown = require('./helpers/setup_and_teardown')
CineIOPeer = require('../src/main')
CallObject = require('../src/call')
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
    CineIOPeer.init('the-public-key')

  afterEach ->
    CineIOPeer.off 'info', @dataTrigger

  beforeEach ->
    @call = new CallObject('Hogwarts Express')

  describe '#answer', ->
    it 'joins the room', (done)->
      @call.answer (err)=>
        expect(@primusStub.write.calledOnce).to.be.true
        args = @primusStub.write.firstCall.args
        expect(args).to.have.length(1)
        expect(args[0].action).to.equal('room-join')
        expect(args[0].room).to.equal('Hogwarts Express')
        expect(args[0].publicKey).to.equal('the-public-key')
        done()

  describe '#reject', ->
    it 'sends a rejection', ->
      @call.reject()
      expect(@primusStub.write.calledOnce).to.be.true
      args = @primusStub.write.firstCall.args
      expect(args).to.have.length(1)
      expect(args[0].action).to.equal('call-reject')
      expect(args[0].room).to.equal('Hogwarts Express')
      expect(args[0].publicKey).to.equal('the-public-key')
