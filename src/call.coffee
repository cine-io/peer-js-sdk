BackboneEvents = require("backbone-events-standalone")
noop = ->

INITIATED = 0
IN_CALL = 1
ENDED = 2

class Participant
  constructor: (@otherIdentity, @room)->
    @state = INITIATED
  # initiator methods
  call: ->
    @state = IN_CALL
    options =
      action: 'call'
      room: @room
      # recipient
      otheridentity: @otherIdentity
    # initiator
    options.identity = CineIOPeer.config.identity.identity if CineIOPeer.config.identity

    CineIOPeer._signalConnection.write options

  cancel: ->
    options =
      action: 'call-cancel'
      room: @room
      # recipient
      otheridentity: @otherIdentity
    # initiator
    options.identity = CineIOPeer.config.identity.identity if CineIOPeer.config.identity
    CineIOPeer._signalConnection.write options
    @state = ENDED

module.exports = class CallObject
  constructor: (@room, @options={})->
    @state = if @options.initiated then IN_CALL else INITIATED
    @participants = {}

    @_createParticipant(options.called)if options.called

  # global call functions
  answer: ->
    @state = IN_CALL
    CineIOPeer.join(@_data.room, callback)

  reject: ->
    @state = ENDED
    options =
      action: 'call-reject'
      room: @room
      # initiator
      otheridentity: @otherIdentity
    # recipient
    options.identity = CineIOPeer.config.identity.identity if CineIOPeer.config.identity

    CineIOPeer._signalConnection.write options

  hangup: (callback=noop)->
    @state = ENDED
    CineIOPeer.leave @room, callback
  # end global call functions

  # individual connection actions
  invite: (otherIdentity, callback=noop)->
    participant = @_createParticipant(otherIdentity)
    participant.call()
    callback()

  cancel: (otherIdentity, callback=noop)->
    participant = @participants[otherIdentity]
    return callback("participant not in room: #{otheridentity}") unless participant
    participant.cancel()
    callback()

  # maybe kick...
  # end individual connection actions

  _createParticipant: (otherIdentity)->
    @participants[otherIdentity] = new Participant(otherIdentity, @room)

BackboneEvents.mixin CallObject::

CineIOPeer = require('./main')
