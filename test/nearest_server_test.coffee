nearestServer = require('../src/nearest_server')
jsonp = require('jsonp')

describe 'nearestServer', ->
  beforeEach ->
    @jsonpStub = sinon.stub nearestServer, '_makeJsonpCall'
    @jsonpStub.callsArgWith 1, null, {some: 'data'}

  afterEach ->
    @jsonpStub.restore()
    nearestServer._reset()

  it 'fetches the nearest server', (done)->
    nearestServer (err, ns)->
      expect(err).to.be.null
      expect(ns).to.deep.equal(some: 'data')
      done()

  it 'will not duplicate fetch when the response has not been returned', (done)->
    called = false
    callback = (err, ns)=>
      expect(ns).to.deep.equal(some: 'data')
      if called
        expect(@jsonpStub.calledOnce).to.be.true
        done()
      called = true

    nearestServer callback
    nearestServer callback

  it 'does not fetch twice', (done)->
    nearestServer (err, ns)=>
      expect(err).to.be.null
      expect(ns).to.deep.equal(some: 'data')
      expect(@jsonpStub.calledOnce).to.be.true
      nearestServer (err, ns)=>
        expect(err).to.be.null
        expect(ns).to.deep.equal(some: 'data')
        expect(@jsonpStub.calledOnce).to.be.true
        done()
