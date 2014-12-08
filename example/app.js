var
  connected = false
, microphoneIsOn = false
, dummyEvent = new Event("dummy")
, qs = {}

function activateButton(event){
  $(event.currentTarget).removeClass('btn-primary').addClass('btn-success')
}
function deactivateButton(event){
  $(event.currentTarget).addClass('btn-primary').removeClass('btn-success')
}


function toggleCamera(e) {
  e.preventDefault()
  if (CineIOPeer.cameraStarted()) {
    CineIOPeer.stopCameraAndMicrophone()
    deactivateButton(e)
  } else {
    CineIOPeer.startCameraAndMicrophone()
    activateButton(e)
  }
}

function toggleMicrophone(e) {
  e.preventDefault()
  if (microphoneIsOn) {
    CineIOPeer.muteMicrophone()
  } else {
    CineIOPeer.unmuteMicrophone()
  }
  microphoneIsOn = !microphoneIsOn
}

function toggleScreenShare(e) {
  e.preventDefault()
  if (CineIOPeer.screenShareStarted()) {
    CineIOPeer.stopScreenShare()
    deactivateButton(e)
  } else {
    CineIOPeer.startScreenShare()
    activateButton(e)
  }
}

function connect(e) {
  if (connected) return;

  e.preventDefault()

  connected = true

  $("#connect").hide()
  $("#disconnect").show()
}

function disconnect(e) {
  if (!connected) return;

  e.preventDefault()

  if (qs.room) {
    CineIOPeer.leave(qs.room)
  }

  connected = false

  $("#disconnect").hide()
  $("#connect").show()
}

$(function() {

  CineIOPeer.on('mediaAdded', function(data) {
    if (data.local || data.remote) {
      var $vid = $(data.videoElement)
      $vid.addClass("col-md-4")
      $("#participants").append($vid)
    } else {
      console.log(data)
      alert('Permission denied.')
    }
  })

  CineIOPeer.on('mediaRejected', function(data) {
    alert('Permission denied.')
  })

  CineIOPeer.on('mediaRemoved', function(data) {
    data.videoElement.remove()
  })

  CineIOPeer.on('call', function(data) {
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
  }

})
