module.exports = (identifier="identifier")->
  beforeEach ->
    sinon.stub window.URL, 'createObjectURL', (mediaStream)->
      return "blob:http%3A//#{window.location.host}/#{identifier}"

  afterEach ->
    window.URL.createObjectURL.restore()
