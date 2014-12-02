var https = require('https')
  , http = require('http')
  , fs = require('fs')
  , express = require('express')
  , connect = require('connect')
  , options = {
      key: fs.readFileSync(__dirname + '/key.pem')
    , cert: fs.readFileSync(__dirname + '/cert.pem')
    , requestCert: true
    , rejectUnauthorized: false
    , agent: false
  }
  , port = process.env.PORT || 9090
  , sslPort = process.env.SSL_PORT || 9443
  , app = connect()
  , httpRouter = express.Router()
  , httpServer = express()
  , httpsServer = https.createServer(options, app)


// redirect http traffic to https
httpRouter.get('*', function(req, res) {
  var hostAndPort = req.headers.host.split(':')
    , hostAndSslPort = hostAndPort[0] + ":" + sslPort
    , redirectUrl = "https://" + hostAndSslPort + req.originalUrl

  return res.redirect(redirectUrl)
})
httpServer.use('*', httpRouter)
httpServer.listen(port, function() {
  console.log("HTTP server started at port", port)
})

// serve static files from https
app.use('/js', connect.static(__dirname + "/../build"))
app.use(connect.static(__dirname))
httpsServer.listen(sslPort, function() {
  console.log("HTTPS server started at port", sslPort)
})
