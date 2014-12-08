https = require("https")
http = require("http")
fs = require("fs")
express = require("express")
express = require("express")
morgan = require('morgan')

port = process.env.PORT or 9090
sslPort = process.env.SSL_PORT or 9443
sslCertsPath = process.env.SSL_CERTS_PATH or __dirname
sslCertFile = "localhost-cine-io.crt"
sslKeyFile = "localhost-cine-io.key"
sslIntermediateCertFiles = [ "COMODORSADomainValidationSecureServerCA.crt", "COMODORSAAddTrustCA.crt", "AddTrustExternalCARoot.crt" ]
sslKey = fs.readFileSync("#{sslCertsPath}/#{sslKeyFile}")
sslCert = fs.readFileSync("#{sslCertsPath}/#{sslCertFile}")
sslCA = (fs.readFileSync "#{sslCertsPath}/#{file}" for file in sslIntermediateCertFiles)
options =
  ca: sslCA
  cert: sslCert
  key: sslKey
  requestCert: true
  rejectUnauthorized: false
  agent: false

# CINE IO API KEYS
keys = require('./fetch_api_keys_from_environment')()
publicKey = keys.publicKey
secretKey = keys.secretKey

app = express()
app.use morgan("dev")
httpServer = http.createServer(app)
httpsServer = https.createServer(options, app)

app.set('views', __dirname + '/views')
app.set('view engine', 'jade')

app.get '', (req, res)->
  if (publicKey || secretKey)
    options =
      title: 'Functionality Example'
      publicKey: publicKey
      room: req.param('room')
      call: req.param('call')
      identity: req.param('identity')
    if options.room || options.identity
      res.render('index', options)
    else
      res.render('use_cases', options)

  else
    res.render('not_configured', {title: 'Not Configured'})

# serve static files
app.use "/js", express.static(__dirname + "/../build")
app.use express.static(__dirname)

httpServer.listen port, ->
  console.log "HTTP server started at http://localhost.cine.io:#{port}"

httpsServer.listen sslPort, ->
  console.log "HTTPS server started at https://localhost.cine.io:#{sslPort}"
