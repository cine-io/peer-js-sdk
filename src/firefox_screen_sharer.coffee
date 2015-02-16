ssBase = require('./screen_share_base')
ScreenSharer = ssBase.ScreenSharer
ScreenShareError = ssBase.ScreenShareError
debug = require('./debug')('cine:peer:firefox_screen_sharer')

class FirefoxScreenSharer extends ScreenSharer
  share: (options, callback)->
    super(options, callback)
    debug "requesting screen share (moz) ..."
    constraints =
      audio: @options.audio
      video:
        mediaSource: "screen"
    navigator.mozGetUserMedia(constraints, @_onStreamReceived.bind(this), @_onError.bind(this))

module.exports = FirefoxScreenSharer
