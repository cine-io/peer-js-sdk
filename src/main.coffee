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

  init: (publicKey)->
    CineIOPeer.config.publicKey = publicKey
    CineIOPeer._signalConnection ||= signalingConnection.connect(publicKey: CineIOPeer.config.publicKey)
    setTimeout CineIOPeer._checkSupport

  identify: (identity, timestamp, signature)->
    # console.log('identifying as', identity)
    CineIOPeer.config.identity = identity
    CineIOPeer._signalConnection.write action: 'identify', identity: identity, timestamp: timestamp, signature: signature, publicKey: CineIOPeer.config.publicKey, client: 'web'

  call: (identity, callback=noop)->
    # console.log('calling', identity)
    CineIOPeer._signalConnection.write action: 'call', otheridentity: identity, publicKey: CineIOPeer.config.publicKey, identity: CineIOPeer.config.identity
    callback()

  join: (room, callback=noop)->
    # console.log('Joining', room)
    CineIOPeer._unsafeJoin(room)
    callback()

  leave: (room)->
    index = CineIOPeer.config.rooms.indexOf(room)
    return CineIOPeer.trigger('error', msg: 'not connected to room', room: room) unless index > -1

    CineIOPeer.config.rooms.splice(index, 1)
    CineIOPeer._signalConnection.write action: 'room-leave', room: room, publicKey: CineIOPeer.config.publicKey

  startMicrophone: (callback=noop)->
    CineIOPeer._startMedia(video: false, audio: true, callback)

  startCameraAndMicrophone: (callback=noop)->
    CineIOPeer._startMedia(video: true, audio: true, callback)

  stopCameraAndMicrophone: (callback=noop)->
    if CineIOPeer.cameraStream?
      CineIOPeer.cameraStream.stop()
      CineIOPeer._signalConnection.removeLocalStream(CineIOPeer.cameraStream)
      CineIOPeer.trigger('mediaRemoved', videoElement: CineIOPeer.config.videoElements[CineIOPeer.cameraStream.id])
      delete CineIOPeer.config.videoElements[CineIOPeer.cameraStream.id]
      CineIOPeer.cameraStream = undefined
    callback()

  cameraStarted: ->
    CineIOPeer.cameraStream?

  screenShareStarted: ->
    CineIOPeer.screenShareStream?

  startScreenShare: (options={}, callback=noop)->
    CineIOPeer._screenSharer ||= screenSharer.get()

    onStreamReceived = (err, screenShareStream)=>
      return CineIOPeer.trigger('error', err) if err
      videoEl = @_createVideoElementFromStream(screenShareStream, mirror: false)
      CineIOPeer.screenShareStream = screenShareStream
      CineIOPeer._signalConnection.addLocalStream(screenShareStream)
      CineIOPeer.trigger 'mediaAdded',
        videoElement: videoEl
        stream: screenShareStream
        type: 'screen'
        local: true
      callback()

    CineIOPeer._screenSharer.share(options, onStreamReceived)

  stopScreenShare: (callback=noop)->
    if CineIOPeer.screenShareStream?
      CineIOPeer.screenShareStream.stop()
      CineIOPeer._signalConnection.removeLocalStream(CineIOPeer.screenShareStream)
      CineIOPeer.trigger('mediaRemoved', videoElement: CineIOPeer.config.videoElements[CineIOPeer.screenShareStream.id])
      delete CineIOPeer.config.videoElements[CineIOPeer.screenShareStream.id]
      CineIOPeer.screenShareStream = undefined
    callback()

  _startMedia: (options, callback=noop)->
    return setTimeout(callback) if CineIOPeer.cameraStream
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
      console.log('got media', response)
      CineIOPeer.trigger 'mediaAdded',
        videoElement: response.videoElement
        stream: response.stream
        type: 'camera'
        local: true
      CineIOPeer._signalConnection.addLocalStream(response.stream)
      callback()

  _checkSupport: ->
    if webrtcSupport.support
      CineIOPeer.trigger 'info', support: true
    else
      CineIOPeer.trigger 'error', support: false

  _unsafeJoin: (room)->
    CineIOPeer.config.rooms.push(room)
    CineIOPeer._signalConnection.write action: 'room-join', room: room, publicKey: 'the-public-key'

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
      CineIOPeer.cameraStream = stream
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
