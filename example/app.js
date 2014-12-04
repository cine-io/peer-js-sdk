var
  connected = false
, cameraIsOn = false
, microphoneIsOn = false
, sharingScreen = false
, dummyEvent = new Event("dummy")
, qs = {}

function toggleCamera(e) {
  e.preventDefault()
  if (connected && cameraIsOn) {
    CineIOPeer.disableCamera()
  } else if (connected && !cameraIsOn) {
    CineIOPeer.enableCamera()
  } else {
    CineIOPeer.startCameraAndMicrophone()
  }
}

function toggleMicrophone(e) {
  e.preventDefault()
  if (connected && microphoneIsOn) {
    CineIOPeer.muteMicrophone()
  } else if (connected && !microphoneIsOn) {
    CineIOPeer.unmuteMicrophone()
  } else {
    CineIOPeer.startMicrophone()
  }
}

function toggleScreenShare(e) {
  e.preventDefault()
  if (connected && sharingScreen) {
    CineIOPeer.stopScreenShare()
  } else if (connected && !sharingScreen) {
    CineIOPeer.startScreenShare()
  } else {
    CineIOPeer.startScreenShare({ audio: true })
  }
}

function connect(e) {
  e.preventDefault()

  CineIOPeer.startCameraAndMicrophone()

  if (qs.room) {
    CineIOPeer.join(qs.room)
  }

  if (qs.identity) {
    CineIOPeer.identify(qs.identity)
  }

  if (qs.call) {
    CineIOPeer.call(qs.call)
  }

  connected = true

  $("#connect").hide()
  $("#disconnect").show()
}

function disconnect(e) {
  e.preventDefault()

  CineIOPeer.stopCameraAndMicrophone()

  if (qs.room) {
    CineIOPeer.leave(qs.room)
  }

  connected = false

  $("#disconnect").hide()
  $("#connect").show()
}

$(function() {

  CineIOPeer.init({ publicKey: "18b4c471bdc2bc1d16ad3cb338108a33" })

  CineIOPeer.on('mediaAdded', function(data) {
    if (data.local) {
      var $vid = $(data.videoElement)
      $vid.addClass("col-md-4")
      $("#participants").append($vid)
    } else {
      alert('Permission denied.')
    }
  })

  CineIOPeer.on('mediaRejected', function(data) {
    alert('Permission denied.')
  })

  CineIOPeer.on('mediaRemoved', function(data) {
    console.log("data:", data)
    data.videoElement.remove()
  })

  CineIOPeer.on('incomingCall', function(data) {
    data.call.answer()
  })

  CineIOPeer.on('mediaRequest', function(data) { /* noop */ })

  CineIOPeer.on('error', function(err) {
    if (typeof(err.support) != "undefined" && !err.support) {
      alert("This browser does not support WebRTC.</h1>")
    } else if (err.msg) {
      alert(err.msg)
    }
  })

  CineIOPeer.on('streamAdded', function(data) {
    var $vid = $(data.videoElement)
    $vid.addClass("col-md-4")
    $("#participants").append($vid)
  })

  CineIOPeer.on('incomingcall', function(data) {
    data.call.answer()
  })

  CineIOPeer.on('streamRemoved', function(data) {
    data.videoEl.remove()
  })

  $("#connect").on("click", connect)
  $("#disconnect").on("click", disconnect)
  $("#camera").on("click", toggleCamera)
  $("#microphone").on("click", toggleMicrophone)
  $("#screen").on("click", toggleScreenShare)

  if (location.search) {
    location.search.substr(1).split("&").forEach(function(item) {
      qs[item.split("=")[0]] = item.split("=")[1]
    })
  }

  if (Object.keys(qs).length) {
    connect(dummyEvent)
    $("#controls").show()
  } else {
    $("#launcher").show()
  }

})
