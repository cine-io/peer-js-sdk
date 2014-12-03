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
httpServer = http.createServer(app)
httpsServer = https.createServer(options, app)

# serve static files
app.use "/js", connect.static(__dirname + "/../build")
app.use connect.static(__dirname)

httpServer.listen port, ->
  console.log "HTTP server started at http://localhost.cine.io:#{port}"

httpsServer.listen sslPort, ->
  console.log "HTTPS server started at https://localhost.cine.io:#{sslPort}"
