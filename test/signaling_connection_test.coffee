setupAndTeardown = require('./helpers/setup_and_teardown')
CineIOPeer = require('../src/main')
SignalingConnection = require('../src/signaling_connection')
stubPrimus = require('./helpers/stub_primus')

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
      it 'is tested'
    describe "leave", ->
      it 'is tested'
    describe "member", ->
      it 'is tested'
    describe "ice", ->
      it 'is tested'
    describe "offer", ->
      it 'is tested'
    describe "answer", ->
      it 'is tested'
    describe 'other actions', ->
      it 'does not throw an exception', ->
        @connection.primus.trigger('data', action: 'UNKNOWN_ACTION')
  describe '.newLocalStream', ->
    it 'is tested'
