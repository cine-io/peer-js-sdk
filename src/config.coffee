protocol = if location.protocol == 'https:' then 'https' else 'http'

if process.env.NODE_ENV == 'production'
  exports.signalingServer = "#{protocol}://signaling.cine.io"
if process.env.NODE_ENV == 'development'
  exports.signalingServer = "#{protocol}://localhost.cine.io:8443"

exports.chromeExtension = "https://chrome.google.com/webstore/detail/ancoeogeclfnhienkmfmeeomadmofhmi"
