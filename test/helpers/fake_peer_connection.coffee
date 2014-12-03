BackboneEvents = require("backbone-events-standalone")

module.exports = class FakePeerConnection
  constructor: (@options)->

    sinon.stub this, 'close'
  close: ->
  addStream: (@stream)->
  processIce: (@remoteIce)->
  offer: (callback)->
    setTimeout ->
      callback(null, "some-offer-string")

BackboneEvents.mixin FakePeerConnection::
