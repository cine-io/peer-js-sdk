if process.env.NODE_ENV == 'production'
  exports.signalingServer = "http://signaling.cine.io"
else
  exports.signalingServer = 'http://localhost:8888'
