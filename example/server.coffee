https = require("https")
http = require("http")
fs = require("fs")
express = require("express")
connect = require("connect")
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

app = connect()
app.use morgan("dev")
httpRouter = express.Router()
httpServer = express()
httpsServer = https.createServer(options, app)

# redirect http traffic to https
httpRouter.get "*", (req, res) ->
  hostAndPort = req.headers.host.split(":")
  hostAndSslPort = hostAndPort[0] + ":" + sslPort
  redirectUrl = "https://" + hostAndSslPort + req.originalUrl
  res.redirect redirectUrl

httpServer.use "*", httpRouter
httpServer.listen port, ->
  console.log "HTTP server started at port", port
  return

# serve static files from https
app.use "/js", connect.static(__dirname + "/../build")
app.use connect.static(__dirname)
httpsServer.listen sslPort, ->
  console.log "HTTPS server started at port", sslPort
  return
