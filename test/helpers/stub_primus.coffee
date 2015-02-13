Primus = require('../../src/vendor/primus')
BackboneEvents = require("backbone-events-standalone")

class PrimusStub
  write: ->

BackboneEvents.mixin PrimusStub::

module.exports = ->
  beforeEach ->
    @primusConnectStub = sinon.stub Primus, 'connect', (url)=>
      @primusStub = new PrimusStub

      sinon.stub @primusStub, 'write'

      @primusStub

  afterEach ->
    @primusConnectStub.restore()
