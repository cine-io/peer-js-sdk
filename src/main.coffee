getUserMedia = require('getusermedia')
attachMediaStream = require('attachmediastream')

defaultOptions =
  video: true
  audio: true
  autoplay: true
  mirror: true
  muted: true

userOrDefault = (userOptions, key)->
  if Object.prototype.hasOwnProperty.call(userOptions, key) then userOptions[key] else defaultOptions[key]

CineIOPeer =
  globalStream: null
  version: "0.0.1"
  config: {}

  init: (options)->
    CineIOPeer.config.name = options.name

  join: (room)->
    CineIOPeer._fetchMedia (err, response)->
      return console.log("ERROR", err) if err
      console.log('connecting')
      document.body.appendChild(response.videoElement)

      signalingConnection.connect(CineIOPeer.config.name, room, response.stream)

  _fetchMedia: (options={}, callback)->
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

  peerAdded: (peerConnection)->
    console.log('peer connection added', CineIOPeer.stream)
    peerConnection.addStream(CineIOPeer.stream)

  remoteStreamAdded: (peerConnection, stream)->
    console.log('remote stream added')
    videoEl = CineIOPeer._createVideoElementFromStream(stream, muted: true)
    document.body.appendChild(videoEl)

  _createVideoElementFromStream: (stream, options={})->
    videoOptions =
      autoplay: userOrDefault(options, 'autoplay')
      mirror: userOrDefault(options, 'mirror')
      muted: userOrDefault(options, 'muted')

    attachMediaStream(stream, null, videoOptions)

window.CineIOPeer = CineIOPeer if typeof window isnt 'undefined'

module.exports = CineIOPeer

signalingConnection = require('./signaling_connection')
