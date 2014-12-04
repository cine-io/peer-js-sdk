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
    # console.log('identifying as', identity)
    CineIOPeer.config.identity = identity
    CineIOPeer._signalConnection.write action: 'identify', identity: identity, publicKey: CineIOPeer.config.publicKey, client: 'web'

  call: (identity, callback=noop)->
    # console.log('calling', identity)
    CineIOPeer._waitForLocalMedia ->
      CineIOPeer._signalConnection.write action: 'call', otheridentity: identity, publicKey: CineIOPeer.config.publicKey, identity: CineIOPeer.config.identity
      callback()

  join: (room, callback=noop)->
    CineIOPeer._waitForLocalMedia ->
      # console.log('Joining', room)
      CineIOPeer._unsafeJoin(room)
      callback()

  leave: (room)->
    index = CineIOPeer.config.rooms.indexOf(room)
    return CineIOPeer.trigger('error', msg: 'not connected to room', room: room) unless index > -1

    CineIOPeer.config.rooms.splice(index, 1)
    CineIOPeer._signalConnection.write action: 'leave', room: room, publicKey: CineIOPeer.config.publicKey

  startMicrophone: (callback)->
    CineIOPeer._startMedia(video: false, audio: true, callback)

  startCameraAndMicrophone: (callback)->
    CineIOPeer._startMedia(video: true, audio: true, callback)

  stopCameraAndMicrophone: (callback=noop)->
    if CineIOPeer.stream?
      CineIOPeer.trigger('mediaRemoved', videoElement: CineIOPeer.config.videoElements[CineIOPeer.stream.id])
      delete CineIOPeer.config.videoElements[CineIOPeer.stream.id]
      CineIOPeer.stream = undefined
    callback()

  _waitForLocalMedia: (callback)->
    setTimeout callback if CineIOPeer._hasMedia()
    CineIOPeer.once 'localMediaRequestSuccess', callback

  _hasMedia: ->
    CineIOPeer.stream?

  _startMedia: (options, callback=noop)->
    return setTimeout(callback) if CineIOPeer.stream
    requestTimeout = setTimeout CineIOPeer._mediaNotReady, 1000
    CineIOPeer._askForMedia options, (err, response)->
      clearTimeout requestTimeout
      if err
        # did not grant permission
        CineIOPeer.trigger 'mediaRejected',
          type: 'camera'
          local: true
        # console.log("ERROR", err)
        return callback(err)
      response
      # console.log('got media', response)
      CineIOPeer.trigger('localMediaRequestSuccess')
      CineIOPeer.trigger 'mediaAdded',
        videoElement: response.videoElement
        stream: response.stream
        type: 'camera'
        local: true
      CineIOPeer._signalConnection.newLocalStream(response.stream)
      callback()

  startScreenShare: (options={}, callback=noop)->
    onStreamReceived = (err, screenShareStream)=>
      return CineIOPeer.trigger('error', err) if err
      videoEl = @_createVideoElementFromStream(screenShareStream)
      CineIOPeer.screenShareStream = screenShareStream
      CineIOPeer._signalConnection.newLocalStream(screenShareStream)
      CineIOPeer.trigger 'mediaAdded',
        videoElement: videoEl
        stream: screenShareStream
        type: 'screen'
        local: true

    screenSharer.get(options, onStreamReceived).share()
    callback()

  stopScreenShare: (callback=noop)->
    if CineIOPeer.screenShareStream?
      CineIOPeer.trigger('mediaRemoved', videoElement: CineIOPeer.config.videoElements[CineIOPeer.screenShareStream.id])
      delete CineIOPeer.config.videoElements[CineIOPeer.screenShareStream.id]
      CineIOPeer.screenShareStream = undefined
    callback()

  _checkSupport: ->
    if webrtcSupport.support
      CineIOPeer.trigger 'info', support: true
    else
      CineIOPeer.trigger 'error', support: false

  _unsafeJoin: (room)->
    CineIOPeer.config.rooms.push(room)
    CineIOPeer._signalConnection.write action: 'join', room: room, publicKey: 'the-public-key'

  _mediaNotReady: ->
    CineIOPeer.trigger('mediaRequest')

  _askForMedia: (options={}, callback)->
    if typeof options == 'function'
      callback = options
      options = {}
    streamDoptions =
      video: userOrDefault(options, 'video')
      audio: userOrDefault(options, 'audio')
    # console.log('fetching media', options)

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
screenSharer = require('./screen_sharer')
