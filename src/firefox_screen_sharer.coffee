ssBase = require('./screen_share_base')
ScreenSharer = ssBase.ScreenSharer
ScreenShareError = ssBase.ScreenShareError

class FirefoxScreenSharer extends ScreenSharer
  share: (options, callback)->
    super(options, callback)
    console.log "requesting screen share (moz) ..."
    constraints =
      audio: @options.audio
      video:
        mediaSource: "screen"
    navigator.mozGetUserMedia(constraints, @_onStreamReceived.bind(this), @_onError.bind(this))

module.exports = FirefoxScreenSharer
