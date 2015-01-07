var qs = {}

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

  e.preventDefault()
  window.location.reload();
}

function disconnect(e) {

  e.preventDefault()

  if (qs.room) {
    CineIOPeer.leave(qs.room)
  }

  $("#disconnect").hide()
  $("#connect").show()
}

$(function() {

  CineIOPeer.on('media-added', function(data) {
    var $vid = $(data.videoElement)
    $vid.addClass("col-md-4")
    $("#participants").append($vid)
  })

  CineIOPeer.on('media-rejected', function(data) {
    alert('Permission denied.')
  })

  CineIOPeer.on('media-removed', function(data) {
    data.videoElement.remove();
  })

  CineIOPeer.on('call', function(data) {
    data.call.answer()
  })

  CineIOPeer.on('extension-required', function(data) {
    var extensionLink = $("<a>", {href: data.url, text: data.type + " screen share extension", target:'_blank'});
    $('#info').append($('<span>', {text: "Please install the "}))
    $('#info').append(extensionLink)
    $('#info').append($('<span>', {text: "."}))
  })

  CineIOPeer.on('media-request', function(data) { /* noop */ })

  CineIOPeer.on('peer-data', function(data) {
    console.log("GOT DATA", data)
    addDataToEl(data.message);
  });
  dataEl = $('#data')
  function addDataToEl(message){
    $('<li>', {text: JSON.stringify(message)}).appendTo(dataEl)
  }

  CineIOPeer.on('error', function(err) {
    if (typeof(err.support) != "undefined" && !err.support) {
      alert("This browser does not support WebRTC.")
    } else if (err.msg) {
      alert(err.msg)
    }
  });

  function sendData(event){
    event.preventDefault();
    var
      text = $('#text'),
      val = text.val();
    CineIOPeer.sendDataToAll({message: val});
    addDataToEl(val);
    text.val('');
  }

  $("#send").on("submit", sendData)
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
    $("#connect").hide()
    $("#disconnect").show()
  }

})
