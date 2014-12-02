if process.env.NODE_ENV == 'production'
  exports.signalingServer = "http://signaling.cine.io"
if process.env.NODE_ENV == 'development'
  exports.signalingServer = 'https://localhost.cine.io:8443'
