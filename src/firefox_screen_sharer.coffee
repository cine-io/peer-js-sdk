ssBase = require('./screen_share_base')
ScreenSharer = ssBase.ScreenSharer
ScreenShareError = ssBase.ScreenShareError

class FirefoxScreenSharer extends ScreenSharer
  share: ->
    console.log "requesting screen share (moz) ..."
    navigator.mozGetUserMedia({
        audio:false,
        video: {
          mediaSource: "screen"
        }
    }, @_onStreamReceived.bind(this), @_onError.bind(this))

module.exports = FirefoxScreenSharer
