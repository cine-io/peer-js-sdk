webrtcSupport = require('webrtcsupport')
debug = require('./debug')('cine:peer:screen_share_base')


class ScreenShareError
  constructor: (@msg, data)->
    for k, v of data
      this[k] = v


class ScreenSharer
  share: (@options, @_callback)->
    return @_callback(new ScreenShareError("Screen sharing requires a browser environment!")) unless window and navigator
    return @_callback(new ScreenShareError("Screen sharing not implemented in this browser / environment.")) unless webrtcSupport.screenSharing

  _onStreamReceived: (stream)->
    debug "Received local stream:", stream
    stream.onended = @_onStreamEnded.bind(this)
    return @_callback(null, stream)

  _onStreamEnded: ->
    debug "Screen share ended."
    CineIOPeer.stopScreenShare()
    return

  _onError: (err)->
    errMsg = if err.name then err.name + (if err.message then " (#{err.message})" else "") else err
    errMsg = "Screen share failed: #{errMsg}"
    console.dir err
    debug errMsg
    return @_callback(new ScreenShareError(errMsg))


module.exports =
  ScreenShareError: ScreenShareError
  ScreenSharer: ScreenSharer

CineIOPeer = require('./main')
