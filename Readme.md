# cine.io peer client

The JavaScript SDK for [cine.io](https://www.cine.io) peer-to-peer communication.


## Installation

```html
<script src="//cdn.cine.io/cineio-peer.js"></script>
```

## Usage

The `CineIOPeer` object is used to start your webcam, microphone, and desktop screen sharing. It can make and recieve calls within your application and join rooms.

#### Init

Start off by initializing CineIOPeer with your public publicKey.

```javascript
CineIOPeer.init(CINE_IO_PUBLIC_KEY);
```
**CINE_IO_PUBLIC_KEY**
This is your public key for a [cine.io](https://www.cine.io) project.

#### Camera, microphone, and desktop screen sharing

CineIOPeer has functions for turning on and off your local media.

#### Rooms






## How to run the example server under SSL in development

1. Obtain the SSL certificate files for localhost.cine.io and save them to your local system.
2. Invoke the server in this way:

   ```bash
   $ SSL_CERTS_PATH=../certificates CINE_IO_PUBLIC_KEY=… CINE_IO_SECRET_KEY=… PORT=9080 SSL_PORT=9443 coffee example/server.coffee
   ```
