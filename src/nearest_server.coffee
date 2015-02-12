jsonp = require('jsonp')
BASE_SERVER_URL = "https://www.cine.io/api/1/-/nearest-server?default=ok"

nearestServer = null
fetchingNearestServer = null
nearestServerCallbacks = null


module.exports = (callback)->
  return callback(null, nearestServer) if nearestServer
  return nearestServerCallbacks.push(callback) if fetchingNearestServer
  fetchingNearestServer = true
  module.exports._makeJsonpCall BASE_SERVER_URL, (err, data)->
    nearestServer = data
    for cb in nearestServerCallbacks
      cb(err, nearestServer)
    nearestServerCallbacks = []
    callback(err, nearestServer)

module.exports._makeJsonpCall = (url, callback)->
  jsonp url, callback

module.exports._reset = ->
  nearestServer = null
  fetchingNearestServer = false
  nearestServerCallbacks = []

module.exports._reset()
# nearestServer = {rtcPublish: "http://docker-local.cine.io:8080"}
# nearestServer = {rtcPublish: "https://docker-local.cine.io:8081"}
# nearestServer = {rtcPublish: "http://localhost.cine.io:8880"}
