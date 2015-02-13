# [cine.io](https://www.cine.io) Peer JS SDK

[![Build Status](https://travis-ci.org/cine-io/peer-js-sdk.svg?branch=master)](https://travis-ci.org/cine-io/peer-js-sdk)

The JavaScript SDK for [cine.io](https://www.cine.io) [peer-to-peer](https://www.cine.io/products/peer) communication.


## Installation

```html
<script src="//cdn.cine.io/cineio-peer.js"></script>
```

## Usage

The `CineIOPeer` object is used for real-time communication between two "peers". It supports video-chat using a [webcam and microphone](#camera-and-microphone) and also allows for sharing a [desktop screen](#screen-sharing). It's possible to [make and recieve calls](#calling) within an application or to [join chat rooms](#rooms). It can also supports [sending data](#sending-data-to-peers) between connected peers.

### Initialize

Start off by initializing CineIOPeer with your public key.

```JavaScript
CineIOPeer.init(CINE_IO_PUBLIC_KEY);
```
**CINE_IO_PUBLIC_KEY**
This is your public key for a [cine.io](https://www.cine.io) project.

### Camera and microphone

#### Turning on and off the camera and microphone

CineIOPeer has functions for turning on and off your camera and/or microphone.

```JavaScript
CineIOPeer.startCameraAndMicrophone(optionalCallback);
CineIOPeer.stopCameraAndMicrophone(optionalCallback);
CineIOPeer.startCamera(optionalCallback);
CineIOPeer.stopCamera(optionalCallback);
CineIOPeer.startMicrophone(optionalCallback);
CineIOPeer.stopMicrophone(optionalCallback);
```

A common workflow is to start by calling `CineIOPeer.startCameraAndMicrophone` and using `CineIOPeer.stopMicrophone` for muting audio. The same can be done with `CineIOPeer.stopCamera`.

Accessing the camera and microphone may result in a native browser popup asking the user for permission to the camera and microphone. As such, to avoid duplicate permission-asks, it is best to use the most appropriate camera and microphone initialization request.

#### Camera and microphone status

CineIOPeer has helpful functions to check the status of the camera and microphone.

```JavaScript
CineIOPeer.cameraRunning();
CineIOPeer.microphoneRunning();
```

### Screen Sharing

Screen Sharing does work but the general state of screen sharing over WebRTC is generally broken all around. Chrome requires an [extension](https://chrome.google.com/webstore/detail/cineio-screen-sharing/ancoeogeclfnhienkmfmeeomadmofhmi). Firefox requires updating browser permissions, or an extension that does it for you (coming soon), which whitelists specific domains. If you need assistance contact [cine.io support](http://support.cine.io).

#### Checking support

To check if your browser supports screen sharing

```JavaScript
var supported = CineIOPeer.screenShareSupported()
```

#### Turning on and off screen sharing

CineIOPeer has functions for turning on and off your desktop screen share.

```JavaScript
CineIOPeer.startScreenShare(optionalCallback);
CineIOPeer.stopScreenShare(optionalCallback);
```

#### Screen Share Status

CineIOPeer has helpful functions to check the status of the desktop screen share.

```JavaScript
CineIOPeer.screenShareRunning();
```

### Creating connections between two or more peers

CineIOPeer can join users together by either rooms or individual calling.

#### Rooms

Rooms are one of the easiest ways to get up and running. When two or more users join a room and they will begin communicating instantly. If the first user leaves the room, the remaining users will still remain in the room and other users can still join. If you join multiple rooms at the same time, the same running streams (camera, microphone, screen) will be sent to all connected peers.

```JavaScript
var room = "the-best-room-ever";
CineIOPeer.join(room, optionalCallback);
```

Leaving a room will close the connection between the user and all of the room users. To leave a room:

```JavaScript
var room = 'the-best-room-ever';
CineIOPeer.leave(room, optionalCallback);
```

There is no built-in room authorization. All rooms are public. Room names are unique per project.

#### Calling

Calling is a super neat feature! But it is a bit more complex to setup. Calling allows users to `identify` and call another user. Other users can be invited to join the conversation. Calling is split up into two sections: `identify` and `call`.

##### Identifying a user

Identifying is done with a secure token generated using your **CINE_IO_SECRET_KEY**.
We don't want anybody to impersonate a different user and therefore we require a secure timestamped generated hash.
This part must be done on your server as it requires your **CINE_IO_SECRET_KEY**.

The pseudo code for generating a secure signature is:

```java
Integer timestamp = getSecondsFromEpoch();
String signatureString = "identity=" + identity + "&timestamp=" + timestamp + secretKey;
String signature = sha1.hexdigest(signatureString);
KeyValueStore response = {"identity": identity, "signature": signature, "timestamp": timestamp};
```

You can find language specific implemtations in our:

* [Ruby Gem](https://github.com/cine-io/cineio-ruby#identity-signature-generation)
* [Node Package](https://github.com/cine-io/cineio-node#identity-signature-generation)
* [Python Egg](https://github.com/cine-io/cineio-python#identity-signature-generation)

This response can now be used in `CineIOPeer`. Identifying a user:

```JavaScript
CineIOPeer.identify(identity, timestamp, signature);
```

Identities are unique per project. Common identity names are user ids.

##### Calling another user

Calling is the easy part. Calling is as simple as:

```JavaScript
CineIOPeer.call(otherIdentity);
```

##### Call Object

When a user makes or recieves a call. They will get, via event callback, a `Call` object. See [Events](#cineiopeer-events).

The Call object provides the following interface:

```JavaScript
callObject.answer() // answer a call
callObject.reject() // reject a call
callObject.invite(identity) // invite another user to join this call
callObject.hangup() // hangup on the call. This will keep the remaining users in the call
```

#### Sending data to peers

`CineIOPeer` allows users to send arbitrary json data between the peers.

```JavaScript
CineIOPeer.sendDataToAll(data)
```

### CineIOPeer Events

```JavaScript

// Media Events
// if the user was asked to grant permission to the camera/microphone/screen share
// This event only fires if the user was prompted for permission and we are waiting for the user to approve the permission. If there is no user approval step, this event does not fire.
CineIOPeer.on('media-request', function(data) {
  if (data.type === 'screen'){
    // requested screen share
  } else{
    // requested camera/microphone
  }
});

// The user rejected the permission to access camera/microphone
CineIOPeer.on('media-rejected', function(data) {
  if (data.type === 'screen'){
    // rejected screen share
  } else{
    // rejected camera/microphone
  }
});

// when local or remote media is added
CineIOPeer.on('media-added', function(data) {
  var videoDOMNode = data.videoElement;
  if (data.local) {
    // local video
    if (data.type === 'screen') {
      // screen share video
    } else {
      // camera stream
    }
  } else {
    // remote video
  }
});

// when local or remote media is removed
CineIOPeer.on('media-removed', function(data) {
  var videoDOMNode = data.videoElement;
  if (data.local) {
    // local video
    if (data.type === 'screen') {
      // screen share video
    } else {
      // camera stream
    }
  } else {
    // remote video
  }
});


// Calling Events
// when a new call comes in
CineIOPeer.on('call', function(data) {
  var call = data.call;
  // handle call (See CallObject above)
});

// when a call was initiated by this user
CineIOPeer.on('call-placed', function(data) {
  var call = data.call
  // handle call (See CallObject above)
});

// when a call was rejecected by the user
CineIOPeer.on('call-reject', function(data) {
  var call = data.call
  // handle call (See CallObject above)
});


// Data Events
// Processing raw json data sent between peers
CineIOPeer.on('peer-data', function(data) {
  // process json data
});


// Misc Events
CineIOPeer.on('error', function(err) {
  if (typeof(err.support) != "undefined" && !err.support) {
    alert("This browser does not support WebRTC.")
  } else if (err.msg) {
    alert(err.msg)
  }
});

```

### WebRTC Broadcast

Cine.io provides a WebRTC to RTMP/HLS bridge to enhance your conference applications with broadcast capabilities.

#### Broadcast your webcam and microphone

To broadcast your webcam and microphone to a cine.io live stream, start by requesting camera and microphone access.

```javascript

CineIOPeer.startCameraAndMicrophone(optionalCallback)

```

##### Starting a webcam and microphone broadcast

```javascript
var streamId = "cine.io stream id";
var password = "stream password";
var optionalCallback = function(error){
  console.log("broadcasting");
};
CineIOPeer.broadcastCameraAndMicrophone(streamId, password, optionalCallback)
```

>The camera and microphone stream must already be started. Here is a complete example:
```javascript
CineIOPeer.startCameraAndMicrophone(function(err) {
  if (err) { return console.log("camera/mic error", err); }
  var streamId = "cine.io stream id";
  var password = "stream password";
  CineIOPeer.broadcastCameraAndMicrophone(streamId, password, function(err) {
    if (err) { return console.log("broadcasting error", err); }
  });
});
```

##### Stopping a webcam and microphone broadcast

```javascript
var optionalCallback = function(error){
  console.log("broadcasting");
};
CineIOPeer.stopCameraAndMicrophoneBroadcast(optionalCallback)
```

##### Checking the status of your camera and microphone broadcast

```javasript
CineIOPeer.isBroadcastingCameraAndMicrophone();
```

#### Broadcast your screen share

To broadcast your desktop to a cine.io live stream, start by requesting screen share access.

```javascript

CineIOPeer.startScreenShare(optionalCallback)

```

##### Starting a screen share broadcast

```javascript
var streamId = "cine.io stream id";
var password = "stream password";
var optionalCallback = function(error){
  console.log("broadcasting");
};
CineIOPeer.broadcastScreenShare(streamId, password, optionalCallback)
```

>The screen share stream must already be started. Here is a complete example:
```javascript
CineIOPeer.startScreenShare(function(err) {
  if (err) { return console.log("screen share error", err); }
  var streamId = "cine.io stream id";
  var password = "stream password";
  CineIOPeer.broadcastScreenShare(streamId, password, function(err) {
    if (err) { return console.log("broadcasting error", err); }
  });
});
```

##### Stopping a screen share broadcast

```javascript
var optionalCallback = function(error){
  console.log("broadcasting");
};
CineIOPeer.stopScreenShareBroadcast(optionalCallback)
```

##### Checking the status of your screen share broadcast

```javasript
CineIOPeer.isBroadcastingScreenShare();
```
