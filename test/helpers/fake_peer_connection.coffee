BackboneEvents = require("backbone-events-standalone")

module.exports = class FakePeerConnection
  constructor: (@options)->
    BackboneEvents.mixin this
    sinon.stub this, 'close'
  close: ->
  addStream: (@stream)->
  offer: (callback)->
    setTimeout ->
      callback(null, "some-offer-string")
