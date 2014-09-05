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
  start: (options={}, callback)->
    if typeof options == 'function'
      callback = options
      options = {}
    streamDoptions =
      video: userOrDefault(options, 'video')
      audio: userOrDefault(options, 'audio')
    console.log('starting', options)
    getUserMedia streamDoptions, (err, stream)=>
      return callback(err) if err
      videoEl = @_createVideoElementFromStream(stream, options)

      callback(null, videoElement: videoEl, stream: stream)
  quickRun: ->
    CineIOPeer.start (err, response)->
      return console.log("ERROR", err) if err
      document.body.appendChild(response.videoElement)
      createPeerConnection(response.stream)
  _createVideoElementFromStream: (stream, options={})->
    videoOptions =
      autoplay: userOrDefault(options, 'autoplay')
      mirror: userOrDefault(options, 'mirror')
      muted: userOrDefault(options, 'muted')

    attachMediaStream(stream, null, videoOptions)



window.CineIOPeer = CineIOPeer if typeof window isnt 'undefined'

module.exports = CineIOPeer

createPeerConnection = require('./create_peer_connection')
