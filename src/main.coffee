getUserMedia = require('getusermedia')
attachMediaStream = require('attachmediastream')
webrtcSupport = require('webrtcsupport')
BackboneEvents = require("backbone-events-standalone")
noop = ->
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
    CineIOPeer.config.publicKey = options.publicKey
    CineIOPeer._signalConnection ||= signalingConnection.connect()
    setTimeout CineIOPeer._checkSupport

  identify: (identity)->
    console.log('identifying as', identity)
    CineIOPeer.config.identity = identity
    CineIOPeer._signalConnection.write action: 'identify', identity: identity, publicKey: CineIOPeer.config.publicKey, client: 'web'

  call: (identity, callback=noop)->
    console.log('calling', identity)
    CineIOPeer.fetchMedia (err)->
      return callback(err) if err
      CineIOPeer._signalConnection.write action: 'call', otheridentity: identity, publicKey: CineIOPeer.config.publicKey, identity: CineIOPeer.config.identity
      callback()

  join: (room, callback=noop)->
    console.log('Joining', room)
    CineIOPeer.fetchMedia (err)->
      return callback(err) if err
      CineIOPeer._unsafeJoin(room)
      callback()

  leave: (room)->
    index = CineIOPeer.config.rooms.indexOf(room)
    return CineIOPeer.trigger('error', msg: 'not connected to room', room: room) unless index > -1

    CineIOPeer.config.rooms.splice(index, 1)
    CineIOPeer._signalConnection.write action: 'leave', room: room, publicKey: CineIOPeer.config.publicKey

  fetchMedia: (callback=noop)->
    return setTimeout(callback) if CineIOPeer.stream
    requestTimeout = setTimeout CineIOPeer._mediaNotReady, 1000
    CineIOPeer._askForMedia (err, response)->
      clearTimeout requestTimeout
      if err
        CineIOPeer.trigger 'media', media: false
        console.log("ERROR", err)
        return callback(err)
      response.media = true
      console.log('got media', response)
      CineIOPeer.trigger 'media', response
      callback()

  screenShare: ->
    screenShare.getStream (err, screenShareStream)=>
      return CineIOPeer.trigger('error', msg: err) if err
      videoEl = @_createVideoElementFromStream(screenShareStream)
      CineIOPeer.screenShareStream = screenShareStream
      signalingConnection.newLocalStream(screenShareStream)
      CineIOPeer.trigger('media', videoElement: videoEl, stream: screenShareStream, media: true)

  _checkSupport: ->
    if webrtcSupport.support
      CineIOPeer.trigger 'info', support: true
    else
      CineIOPeer.trigger 'error', support: false

  _unsafeJoin: (room)->
    CineIOPeer.config.rooms.push(room)
    CineIOPeer._signalConnection.write action: 'join', room: room, publicKey: 'the-public-key'

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

    CineIOPeer._unsafeGetUserMedia streamDoptions, (err, stream)=>
      return callback(err) if err
      videoEl = @_createVideoElementFromStream(stream, options)
      CineIOPeer.stream = stream
      callback(null, videoElement: videoEl, stream: stream)

  _unsafeGetUserMedia: (options, callback)->
    getUserMedia options, callback

  _createVideoElementFromStream: (stream, options={})->
    videoOptions =
      autoplay: userOrDefault(options, 'autoplay')
      mirror: userOrDefault(options, 'mirror')
      muted: userOrDefault(options, 'muted')
    videoEl = attachMediaStream(stream, null, videoOptions)
    CineIOPeer.config.videoElements[stream.id] = videoEl
    videoEl

  _getVideoElementFromStream: (stream)->
    CineIOPeer.config.videoElements[stream.id]


CineIOPeer.reset()
BackboneEvents.mixin CineIOPeer

window.CineIOPeer = CineIOPeer if typeof window isnt 'undefined'

module.exports = CineIOPeer

signalingConnection = require('./signaling_connection')
screenShare = require('./screen_share')
