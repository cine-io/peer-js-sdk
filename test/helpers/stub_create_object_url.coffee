inPhantom = typeof window.URL == 'undefined'
module.exports = (identifier="identifier")->
  if inPhantom
    beforeEach ->
      window.URL = {createObjectURL: ->}

    afterEach ->
      window.URL

  beforeEach ->
    sinon.stub window.URL, 'createObjectURL', (mediaStream)->
      return "blob:http%3A//#{window.location.host}/#{identifier}"

  afterEach ->
    window.URL.createObjectURL.restore()
