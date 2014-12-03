ScreenShare =
  getStream: (cb)->
    @_init cb

    if navigator.webkitGetUserMedia
      console.log "requesting screen share (webkit) ..."
      #window.postMessage({ name: "cineScreenShare" }, "*")
    else if navigator.mozGetUserMedia
      console.log "requesting screen share (moz) ..."
      navigator.mozGetUserMedia({
          audio:false,
          video: {
            mediaSource: "screen"
          }
      }, @_onStreamReceived.bind(this), @_onError.bind(this))

  _init: (cb)->
    return cb("No window object!") unless window
    return cb("No navigator object!") unless navigator
    return cb("Screen sharing not implemented in this browser.") unless navigator.webkitGetUserMedia or navigator.mozGetUserMedia
    @_callback = cb
    window.addEventListener("message", @_receiveMessage.bind(this), false)

  _receiveMessage: (event)->
    console.log "received:", event
    switch event.data.name
      when "cineScreenShareHasExtension"
        console.log "cine.io screen share extension is installed."
        window.postMessage({ name: "cineScreenShare" }, "*")
        return
      when "cineScreenShareResponse"
        console.log this
        return @_onScreenShareResponse(event.data.id)

  _onScreenShareResponse: (id)->
    return @_callback("Screen access rejected.") unless id
    navigator.webkitGetUserMedia({
        audio:false,
        video: {
          mandatory: {
            chromeMediaSource: "desktop",
            chromeMediaSourceId: id
          }
        }
    }, @_onStreamReceived.bind(this), @_onError.bind(this))
    return

  _onStreamReceived: (stream)->
    console.log "Received local stream:", stream
    stream.onended = @_onStreamEnded.bind(this)
    return @_callback(null, stream)

  _onStreamEnded: ->
    console.log "Screen share ended."
    return

  _onError: (err)->
    errMsg = if err.name then err.name + (if err.message then " (#{err.message})" else "") else err
    errMsg = "Screen share failed: #{errMsg}"
    console.log errMsg
    return @_callback(errMsg)

module.exports = ScreenShare
