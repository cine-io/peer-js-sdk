ssBase = require('./screen_share_base')
ScreenSharer = ssBase.ScreenSharer
ScreenShareError = ssBase.ScreenShareError

class FirefoxScreenSharer extends ScreenSharer
  share: (options, callback)->
    super(options, callback)
    console.log "requesting screen share (moz) ..."
    navigator.mozGetUserMedia({
        audio: @options.audio,
        video: {
          mediaSource: "screen"
        }
    }, @_onStreamReceived.bind(this), @_onError.bind(this))

module.exports = FirefoxScreenSharer
