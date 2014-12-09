# cine.io peer client

Use with the [signaling server](https://github.com/cine-io/signaling-server).

needs primus to be loaded http://cine-io-signaling.herokuapp.com/primus/primus.js


## How to run the example server under SSL in development

1. Obtain the SSL certificate files for localhost.cine.io and save them to your local system.
2. Invoke the server in this way:

   ```bash
   $ SSL_CERTS_PATH=../certificates CINE_IO_PUBLIC_KEY=… CINE_IO_SECRET_KEY=… PORT=9080 SSL_PORT=9443 coffee example/server.coffee
   ```
