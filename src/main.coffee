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

  startCameraAndMicrophone: (callback=noop)->
    CineIOPeer._startMedia(video: true, audio: true, callback)

  stopCameraAndMicrophone: (callback=noop)->
    if CineIOPeer.microphoneStream
      CineIOPeer._removeStream(CineIOPeer.microphoneStream)
      delete CineIOPeer.microphoneStream
    if CineIOPeer.cameraStream
      CineIOPeer._removeStream(CineIOPeer.cameraStream)
      delete CineIOPeer.cameraStream
    if CineIOPeer.cameraAndMicrophoneStream
      CineIOPeer._removeStream(CineIOPeer.cameraAndMicrophoneStream)
      delete CineIOPeer.cameraAndMicrophoneStream
    callback()

  startMicrophone: (callback=noop)->
    if CineIOPeer._audioCapableStreams().length > 0
      CineIOPeer._unmuteAudio()
      return callback()
    if CineIOPeer.cameraStream && !CineIOPeer.mutedCamera
      CineIOPeer._removeStream(CineIOPeer.cameraStream, silent: true)
      delete CineIOPeer.cameraStream
      return CineIOPeer.startCameraAndMicrophone(callback)
    CineIOPeer._startMedia(video: false, audio: true, callback)

  stopMicrophone: (callback=noop)->
    if CineIOPeer.microphoneStream
      CineIOPeer._removeStream(CineIOPeer.microphoneStream)
      delete CineIOPeer.microphoneStream
    if CineIOPeer.cameraAndMicrophoneStream
      # if the camera is muted, remove the stream all together
      if CineIOPeer.mutedCamera
        CineIOPeer._removeStream(CineIOPeer.cameraAndMicrophoneStream)
        delete CineIOPeer.cameraAndMicrophoneStream
      # the camera is still on, keep the stream around and just remove the video
      else
        CineIOPeer._muteAudio()
    callback()

  startCamera: (callback=noop)->
    if CineIOPeer._cameraCapableStreams().length > 0
      CineIOPeer._unmuteCamera()
      return callback()
    if CineIOPeer.microphoneStream && !CineIOPeer.mutedMicrophone
      CineIOPeer._removeStream(CineIOPeer.microphoneStream, silent: true)
      delete CineIOPeer.microphoneStream
      return CineIOPeer.startCameraAndMicrophone(callback)
    CineIOPeer._startMedia(video: true, audio: false, callback)

  stopCamera: (callback=noop)->
    if CineIOPeer.cameraStream
      CineIOPeer._removeStream(CineIOPeer.cameraStream)
      delete CineIOPeer.cameraStream
    if CineIOPeer.cameraAndMicrophoneStream
      # if the microphone is muted, remove the stream all together
      if CineIOPeer.mutedMicrophone
        CineIOPeer._removeStream(CineIOPeer.cameraAndMicrophoneStream)
        delete CineIOPeer.cameraAndMicrophoneStream
      # the microphone is still on, keep the stream around and just remove the video
      else
        CineIOPeer._muteCamera()
    callback()

  cameraRunning: ->
    return true if CineIOPeer.cameraStream
    CineIOPeer.cameraAndMicrophoneStream && !CineIOPeer.mutedCamera

  screenShareRunning: ->
    CineIOPeer.screenShareStream?

  microphoneRunning: ->
    return true if CineIOPeer.microphoneStream?
    CineIOPeer._audioCapableStreams().length > 0 && !CineIOPeer.mutedMicrophone

  startScreenShare: (options={}, callback=noop)->
    if typeof options == 'function'
      callback = options
      options = {}
    CineIOPeer._screenSharer ||= screenSharer.get()

    onStreamReceived = (err, screenShareStream)=>
      if err
        CineIOPeer.trigger 'mediaRejected',
          type: 'screen'
          local: true
        return callback(err)
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
    return callback() unless CineIOPeer.screenShareRunning()
    CineIOPeer._removeStream(CineIOPeer.screenShareStream)
    delete CineIOPeer.screenShareStream
    callback()

  _muteAudio: ->
    CineIOPeer._muteStreamAudio(stream) for stream in CineIOPeer.localStreams()
    CineIOPeer.mutedMicrophone = true

  _muteCamera: ->
    CineIOPeer._muteStreamVideo(stream) for stream in CineIOPeer._cameraCapableStreams()
    CineIOPeer.mutedCamera = true

  _unmuteAudio: ->
    unmuteStream = CineIOPeer._audioCapableStreams()[0]
    if unmuteStream
      CineIOPeer._unmuteStreamAudio(unmuteStream)
    else
      CineIOPeer.startMicrophone()
    delete CineIOPeer.mutedMicrophone

  _unmuteCamera: ->
    unmuteStream = CineIOPeer._cameraCapableStreams()[0]
    if unmuteStream
      CineIOPeer._unmuteStreamVideo(unmuteStream)
    else
      CineIOPeer.startCamera()
    delete CineIOPeer.mutedCamera

  _removeStream: (stream, options={})->
    stream.stop()
    CineIOPeer._signalConnection.removeLocalStream(stream, options)
    CineIOPeer.trigger('mediaRemoved', local: true, videoElement: CineIOPeer.config.videoElements[stream.id])
    delete CineIOPeer.config.videoElements[stream.id]

  _muteStreamAudio: (stream)->
    return unless stream
    CineIOPeer._disableTracks(stream.getAudioTracks())

  _unmuteStreamAudio: (stream)->
    return unless stream
    CineIOPeer._enableTracks(stream.getAudioTracks())

  _muteStreamVideo: (stream)->
    return unless stream
    CineIOPeer._disableTracks(stream.getVideoTracks())

  _unmuteStreamVideo: (stream)->
    return unless stream
    CineIOPeer._enableTracks(stream.getVideoTracks())

  _enableTracks: (tracks)->
    track.enabled = true for track in tracks
  _disableTracks: (tracks)->
    track.enabled = false for track in tracks

  localStreams: ->
    streams = []
    streams.push CineIOPeer.cameraAndMicrophoneStream if CineIOPeer.cameraAndMicrophoneStream
    streams.push CineIOPeer.cameraStream if CineIOPeer.cameraStream
    streams.push CineIOPeer.microphoneStream if CineIOPeer.microphoneStream
    streams.push CineIOPeer.screenShareStream if CineIOPeer.screenShareStream
    streams

  _cameraCapableStreams: ->
    streams = []
    streams.push CineIOPeer.cameraAndMicrophoneStream if CineIOPeer.cameraAndMicrophoneStream
    streams.push CineIOPeer.cameraStream if CineIOPeer.cameraStream
    streams

  _audioCapableStreams: ->
    streams = []
    streams.push CineIOPeer.cameraAndMicrophoneStream if CineIOPeer.cameraAndMicrophoneStream
    streams.push CineIOPeer.microphoneStream if CineIOPeer.microphoneStream
    streams

  _startMedia: (options, callback=noop)->
    if CineIOPeer.cameraAndMicrophoneStream && options.video && options.audio
      return setTimeout(callback)
    if CineIOPeer.cameraStream && options.video
      return setTimeout(callback)
    if CineIOPeer.microphoneStream && options.audio
      return setTimeout(callback)
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
      if options.video && options.audio
        CineIOPeer.cameraAndMicrophoneStream = response.stream
      else if options.video
        CineIOPeer.cameraStream = response.stream
      else if options.audio
        CineIOPeer.microphoneStream = response.stream

      CineIOPeer.trigger 'mediaAdded',
        videoElement: response.videoElement
        stream: response.stream
        type: 'camera'
        video: options.video
        audio: options.audio
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
