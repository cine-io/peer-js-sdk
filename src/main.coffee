getUserMedia = require('getusermedia')
attachMediaStream = require('attachmediastream')
webrtcSupport = require('webrtcsupport')
BackboneEvents = require("backbone-events-standalone")

defaultOptions =
  video: true
  audio: true
  autoplay: true
  mirror: true
  muted: true

userOrDefault = (userOptions, key)->
  if Object.prototype.hasOwnProperty.call(userOptions, key) then userOptions[key] else defaultOptions[key]

CineIOPeer =
  version: "0.0.1"
  reset: ->
    CineIOPeer.config = {rooms: [], videoElements: {}}
  init: (options={})->
    CineIOPeer.config.apiKey = options.apiKey
    CineIOPeer._signalConnection ||= signalingConnection.connect()
    setTimeout CineIOPeer._checkSupport

  identify: (identity)->
    console.log('identifying as', identity)
    CineIOPeer.config.identity = identity
    CineIOPeer._signalConnection.write action: 'identify', identity: identity, apikey: CineIOPeer.config.apiKey, client: 'web'

  call: (identity)->
    console.log('calling', identity)
    CineIOPeer._fetchMediaSafe ->
      CineIOPeer._signalConnection.write action: 'call', otheridentity: identity, apikey: CineIOPeer.config.apiKey, identity: CineIOPeer.config.identity

  join: (room)->
    CineIOPeer._fetchMediaSafe ->
      console.log('Joining', room)
      CineIOPeer._unsafeJoin(room)

  leave: (room)->
    index = CineIOPeer.config.rooms.indexOf(room)
    return CineIOPeer.trigger('error', msg: 'not connected to room', room: room) unless index > -1

    CineIOPeer.config.rooms.splice(index, 1)
    CineIOPeer._signalConnection.write action: 'leave', room: room

  screenShare: ->
    _getScreenShareStream (screenShareStream)->
      CineIOPeer.screenShareStream = screenShareStream
      CineIOPeer.signalingConnection.newLocalStream(screenShareStream)

  _checkSupport: ->
    CineIOPeer.trigger 'error', support: false unless webrtcSupport.support

  _unsafeJoin: (room)->
    CineIOPeer.config.rooms.push(room)
    CineIOPeer._signalConnection.write action: 'join', room: room

  _fetchMediaSafe: (callback)->
    return callback() if CineIOPeer.stream
    requestTimeout = setTimeout CineIOPeer._mediaNotReady, 1000
    CineIOPeer._askForMedia (err, response)->
      clearTimeout requestTimeout
      if err
        CineIOPeer.trigger 'media', media: false
        console.log("ERROR", err)
        return
      response.media = true
      console.log('got media', response)
      CineIOPeer.trigger 'media', response
      callback()

  _mediaNotReady: ->
    CineIOPeer.trigger('media-request')

  _askForMedia: (options={}, callback)->
    if typeof options == 'function'
      callback = options
      options = {}
    streamDoptions =
      video: userOrDefault(options, 'video')
      audio: userOrDefault(options, 'audio')
    console.log('fetching media', options)

    getUserMedia streamDoptions, (err, stream)=>
      return callback(err) if err
      videoEl = @_createVideoElementFromStream(stream, options)
      CineIOPeer.stream = stream
      callback(null, videoElement: videoEl, stream: stream)

  _createVideoElementFromStream: (stream, options={})->
    videoOptions =
      autoplay: userOrDefault(options, 'autoplay')
      mirror: userOrDefault(options, 'mirror')
      muted: userOrDefault(options, 'muted')
    videoEl = attachMediaStream(stream, null, videoOptions)
    videoElements[stream.id] = videoEl
    videoEl

  _getVideoElementFromStream: (stream)->
    videoElements[stream.id]


CineIOPeer.reset()
BackboneEvents.mixin CineIOPeer

window.CineIOPeer = CineIOPeer if typeof window isnt 'undefined'

module.exports = CineIOPeer

signalingConnection = require('./signaling_connection')
