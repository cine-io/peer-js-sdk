BackboneEvents = require("backbone-events-standalone")

module.exports = class FakePeerConnection
  constructor: (@options)->
    sinon.stub this, 'close'
    sinon.spy this, 'answer'
    sinon.spy this, 'offer'

  close: ->
  addStream: (@stream)->
  processIce: (@remoteIce)->
  handleOffer: (@remoteOffer, callback)->
    setTimeout ->
      callback(null)
  handleAnswer: (@remoteAnswer)->
  offer: (callback)->
    setTimeout ->
      callback(null, "some-offer-string")
  answer: (callback)->
    setTimeout ->
      callback(null, "some-answer-string")

BackboneEvents.mixin FakePeerConnection::
