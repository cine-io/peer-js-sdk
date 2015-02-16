Config = require('./config')
ssBase = require('./screen_share_base')
ScreenSharer = ssBase.ScreenSharer
ScreenShareError = ssBase.ScreenShareError
debug = require('./debug')('cine:peer:chrome_screen_sharer')

class ChromeScreenSharer extends ScreenSharer
  constructor: ->
    super()
    @_extensionInstalled = false
    @_extensionReplyTries = 0

    # Add a listener for "message" events on the window, then send a message
    # to see if the extension is installed. If it is, it will post a message
    # named "cineScreenShareHasExtension" (see _receiveMessage method).
    window.addEventListener("message", @_receiveMessage.bind(this), false)
    window.postMessage({ name: "cineScreenShareCheckForExtension" }, "*")

  share: (options, callback)->
    super(options, callback)
    @_shareAfterExtensionReplies()

  _shareAfterExtensionReplies: ->
    return @_callback(
      new ScreenShareError(
        "Screen sharing in chrome requires the cine.io Screen Sharing extension.",
        extensionRequired: true
        type: 'chrome'
        url: Config.chromeExtension)
      ) unless @_extensionInstalled or (++@_extensionReplyTries < 3)

    if @_extensionInstalled
      window.postMessage({ name: "cineScreenShare" }, "*")
    else
      debug "Waiting for the screen sharing extension reply ..."
      setTimeout(@_shareAfterExtensionReplies.bind(this), 100)

  _receiveMessage: (event)->
    debug "received:", event
    switch event.data.name
      when "cineScreenShareHasExtension"
        debug "cine.io screen share extension is installed."
        @_extensionInstalled = true
        return
      when "cineScreenShareResponse"
        return @_onScreenShareResponse(event.data.id)

  _onScreenShareResponse: (id)=>
    return @_callback(new ScreenShareError("Screen access rejected.")) unless id
    debug "ossr id =", id
    screenShareOptions =
      # audio sharing with desktop is not allowed in chrome
      # https://code.google.com/p/chromium/issues/detail?id=223639
      audio: false

      video:
        mandatory:
          chromeMediaSource: "desktop"
          chromeMediaSourceId: id
    navigator.webkitGetUserMedia(screenShareOptions, @_onStreamReceived.bind(this), @_onError.bind(this))

module.exports = ChromeScreenSharer
