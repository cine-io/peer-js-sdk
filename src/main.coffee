getUserMedia = require('getusermedia')
attachMediaStream = require('attachmediastream')
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
  globalStream: null
  version: "0.0.1"
  config: {}
  _config: {}
  init: (options={})->
    CineIOPeer.config.apiKey = options.apiKey
    CineIOPeer._signalConnection ||= signalingConnection.connect()

  identify: (identity)->
    console.log('identifying as', identity)
    CineIOPeer.config.identity = identity
    CineIOPeer._signalConnection.write action: 'identify', identity: identity, apikey: CineIOPeer.config.apiKey

  call: (identity)->
    console.log('calling', identity)
    CineIOPeer._fetchMediaSafe ->
      CineIOPeer._signalConnection.write action: 'call', otheridentity: identity, apikey: CineIOPeer.config.apiKey, identity: CineIOPeer.config.identity

  join: (room)->
    CineIOPeer._fetchMediaSafe ->
      console.log('Joining', room)
      CineIOPeer._unsafeJoin(room)

  _unsafeJoin: (room)->
    CineIOPeer._signalConnection.write action: 'join', room: room

  _fetchMediaSafe: (callback)->
    return callback() if CineIOPeer.stream
    CineIOPeer._askForMedia (err, response)->
      return console.log("ERROR", err) if err
      console.log('got media')
      CineIOPeer.trigger 'media', response
      callback()

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

    attachMediaStream(stream, null, videoOptions)

BackboneEvents.mixin CineIOPeer

window.CineIOPeer = CineIOPeer if typeof window isnt 'undefined'

module.exports = CineIOPeer

signalingConnection = require('./signaling_connection')
