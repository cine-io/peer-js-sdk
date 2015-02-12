BackboneEvents = require("backbone-events-standalone")

class FakeBrowserPeerConnection
  constructor: ->
    @localDescription = null
  offered: ->
    @localDescription = 'full local description'
module.exports = class FakePeerConnection
  constructor: (@options)->
    sinon.stub this, 'close'
    sinon.spy this, 'answer'
    sinon.spy this, 'offer'
    sinon.spy this, 'handleAnswer'
    @streams = []
    @offered = false
    @pc = new FakeBrowserPeerConnection
  close: ->
  addStream: (stream)->
    @streams.push(stream)
  removeStream: (stream)->
    index = @streams.indexOf(stream)
    @streams.splice(index, 1) if index > -1
  processIce: (@remoteIce)->
  handleOffer: (@remoteOffer, callback)->
    setTimeout ->
      callback(null)
  handleAnswer: (@remoteAnswer)->
  offer: (constraints, callback)->
    if typeof constraints == 'function'
      callback = constraints
      constraints = {}
    setTimeout =>
      @offered = true
      @pc.offered()
      callback(null, "some-offer-string")
  answer: (callback)->
    setTimeout ->
      callback(null, "some-answer-string")

BackboneEvents.mixin FakePeerConnection::
