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

    CineIOPeer._signalConnection.write options

  cancel: ->
    @state = ENDED
    options =
      action: 'call-cancel'
      room: @room
      # recipient
      otheridentity: @otherIdentity

    CineIOPeer._signalConnection.write options

  left: ->
    @state = ENDED

  joined: ->
    @state = IN_CALL

module.exports = class CallObject
  constructor: (@room, @options={})->
    @state = if @options.initiated then IN_CALL else INITIATED
    @participants = {}

    @_createParticipant(@options.called) if @options.called

  # global call functions
  answer: (callback=noop)->
    @state = IN_CALL
    CineIOPeer.join(@room, callback)

  isInCall: ->
    @state == IN_CALL

  isEnded: ->
    @state == ENDED

  reject: (callback=noop)->
    @state = ENDED
    options =
      action: 'call-reject'
      room: @room

    CineIOPeer._signalConnection.write options
    callback()

  hangup: (callback=noop)->
    @state = ENDED
    CineIOPeer.leave @room, callback
    @_cancelOutgoingCalls()

  left: (otherIdentity)->
    participant = @participants[otherIdentity]
    return unless participant
    participant.left()

  joined: (otherIdentity)->
    participant = @_createParticipant(otherIdentity)
    participant.joined()
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

  _cancelOutgoingCalls: ->
    participant.cancel() for otherIdentity, participant of @participants
  # maybe kick...
  # end individual connection actions

  _createParticipant: (otherIdentity)->
    existingParticipant = @participants[otherIdentity]
    return existingParticipant if existingParticipant
    @participants[otherIdentity] = new Participant(otherIdentity, @room)

BackboneEvents.mixin CallObject::

CineIOPeer = require('./main')
