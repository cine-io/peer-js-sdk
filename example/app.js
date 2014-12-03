$(function() {

  CineIOPeer.init({ publicKey: "18b4c471bdc2bc1d16ad3cb338108a33" })

  CineIOPeer.on('media', function(data) {
    if (data.media) {
      var $vid = $(data.videoElement)
      $vid.addClass("col-md-4")
      $("#participants").append($vid)
    } else {
      alert('Permission denied.')
    }
  })

  CineIOPeer.on('media-request', function(data) {
    //document.write("<h1>Asking for media yooo.</h1>");
  });

  CineIOPeer.on('error', function(err) {
    if (typeof(err.support) != "undefined" && !err.support) {
      alert("This browser does not support WebRTC.</h1>")
    } else if (err.msg) {
      alert(err.msg)
    }
  })

  CineIOPeer.on('streamAdded', function(data) {
    var participantsDiv = document.getElementById('participants')
    participantsDiv.appendChild(data.videoElement)
  })

  CineIOPeer.on('incomingcall', function(data) {
    data.call.answer()
  })

  CineIOPeer.on('streamRemoved', function(data) {
    data.videoEl.remove()
  })

  var qs = {}
  if (location.search) {
    location.search.substr(1).split("&").forEach(function(item) {
      qs[item.split("=")[0]] = item.split("=")[1]
    })
  }

  if (Object.keys(qs).length) {
    if (qs.room) {
      CineIOPeer.join(qs.room)
    }

    if (qs.identity){
      CineIOPeer.identify(qs.identity)
    }

    if (qs.call){
      CineIOPeer.call(qs.call)
    }

    if (qs.screenshare) {
      CineIOPeer.screenShare()
    }
  } else {
    $("#instructions").show()
  }

})
