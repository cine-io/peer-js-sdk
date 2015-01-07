ScreenShareError = require('./screen_share_base').ScreenShareError
browserDetect = require('./browser_detect')

ScreenSharer =
  get: (options={}, cb)->
    options.audio = false unless options.hasOwnProperty("audio")

    if browserDetect.isChrome
      ChromeScreenSharer = require('./chrome_screen_sharer')
      return new ChromeScreenSharer(options, cb)
    else if browserDetect.isFirefox
      FirefoxScreenSharer = require('./firefox_screen_sharer')
      return new FirefoxScreenSharer(options, cb)
    else
      return cb(new ScreenShareError("Screen sharing not implemented in this browser / environment."))


module.exports = ScreenSharer
