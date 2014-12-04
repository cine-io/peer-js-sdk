webrtcSupport = require('webrtcsupport')


class ScreenShareError
  constructor: (@msg, data)->
    for k, v of data
      this[k] = v


class ScreenSharer
  constructor: (@options, @_callback)->
    return @_callback(new ScreenShareError("Screen sharing requires a browser environment!")) unless window and navigator
    return @_callback(new ScreenShareError("Screen sharing not implemented in this browser / environment.")) unless webrtcSupport.screenSharing

  share: ->
    @_callback("NOT IMPLEMENTED")

  _onStreamReceived: (stream)->
    console.log "Received local stream:", stream
    stream.onended = @_onStreamEnded.bind(this)
    return @_callback(null, stream)

  _onStreamEnded: ->
    console.log "Screen share ended."
    CineIOPeer.stopScreenShare()
    return

  _onError: (err)->
    errMsg = if err.name then err.name + (if err.message then " (#{err.message})" else "") else err
    errMsg = "Screen share failed: #{errMsg}"
    console.log errMsg
    return @_callback(new ScreenShareError(errMsg))


module.exports =
  ScreenShareError: ScreenShareError
  ScreenSharer: ScreenSharer

CineIOPeer = require('./main')
