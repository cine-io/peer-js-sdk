var
  connected = false
, dummyEvent = new Event("dummy")
, qs = {}

function activateButton(id){
  $("#"+id).removeClass('btn-primary').addClass('btn-success')
}

function deactivateButton(id){
  $("#"+id).addClass('btn-primary').removeClass('btn-success')
}

function recalculateLayout(err){
  if (err){
    console.error("GOT error", err)
  }
  if (CineIOPeer.cameraRunning()){
    activateButton("camera")
  }else{
    deactivateButton("camera")
  }
  if (CineIOPeer.microphoneRunning()){
    activateButton("microphone")
  }else{
    deactivateButton("microphone")
  }
  if (CineIOPeer.cameraRunning() && CineIOPeer.microphoneRunning()){
    activateButton("camera-and-microphone")
  }else{
    deactivateButton("camera-and-microphone")
  }
  if (CineIOPeer.screenShareRunning()){
    activateButton("screen")
  }else{
    deactivateButton("screen")
  }

}


function toggleCamera(e) {
  e.preventDefault()
  if (CineIOPeer.cameraRunning()) {
    CineIOPeer.stopCamera(recalculateLayout)
  } else {
    CineIOPeer.startCamera(recalculateLayout)
  }
}
function toggleCameraAndMicrophone(e) {
  e.preventDefault()
  if (CineIOPeer.cameraRunning()) {
    CineIOPeer.stopCameraAndMicrophone(recalculateLayout)
  } else {
    CineIOPeer.startCameraAndMicrophone(recalculateLayout)
  }
}

function toggleMicrophone(e) {
  e.preventDefault()
  if (CineIOPeer.microphoneRunning()) {
    CineIOPeer.stopMicrophone(recalculateLayout)
  } else {
    CineIOPeer.startMicrophone(recalculateLayout)
  }
}

function toggleScreenShare(e) {
  e.preventDefault()
  if (CineIOPeer.screenShareRunning()) {
    CineIOPeer.stopScreenShare(recalculateLayout)
  } else {
    CineIOPeer.startScreenShare(recalculateLayout)
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
  $("#camera-and-microphone").on("click", toggleCameraAndMicrophone)
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
