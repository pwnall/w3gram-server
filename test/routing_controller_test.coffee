request = require 'request'
sinon = require 'sinon'

describe 'HTTP server', ->
  before (done) ->
    @server = w3gram_test_config.server()
    @appCache = w3gram_test_config.appCache()
    @appList = w3gram_test_config.appList()

    @appList.teardown (error) =>
      if error
        console.error error
        process.exit 1
      @server.listen =>
        @httpRoot = @server.httpUrl()
        done()

  after (done) ->
    @server.close done

  beforeEach (done) ->
    @sandbox = sinon.sandbox.create()
    @appCache.reset()
    @appList.setup (error) ->
      if error
        console.error error
        process.exit 1
      done()

  afterEach (done) ->
    @sandbox.restore()
    @appCache.reset()
    @appList.teardown (error) ->
      if error
        console.error error
        process.exit 1
      done()

  beforeEach (done) ->
    appOptions =
      name: 'routing test app', origin: 'https://test.app.com'
    @appList.create appOptions, (error, app) =>
      expect(error).to.equal null
      @app = app
      done()

  describe 'OPTIONS /route', ->
    it 'returns a CORS-compliant response', (done) ->
      requestOptions =
        url: "#{@httpRoot}/route/#{@app.listenerId('tablet-device-id')}"
        method: 'OPTIONS'
        headers:
          origin: 'https://example.push.consumer.com'
      request requestOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 204
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['access-control-allow-methods']).to.equal(
          'POST')
        expect(response.headers['access-control-max-age']).to.equal(
          '31536000')
        done()

  describe 'POST /route', ->
    beforeEach ->
      @postOptions =
        url: "#{@httpRoot}/route/#{@app.listenerId('tablet-device-id')}"
        headers:
          'content-type': 'application/json; charset=utf-8'
          'host': 'w3gram.server.com:8080'
        body: '{}'

    it 'processes a correct routing request', (done) ->
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 200
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        listenerId = @app.listenerId 'tablet-device-id'
        expect(json.listen).to.equal(
            "ws://w3gram.server.com:8080/ws/#{listenerId}")
        done()

    it 'processes a correct CORS routing request', (done) ->
      @postOptions.headers['origin'] = 'https://test.app.com'
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 200
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        listenerId = @app.listenerId 'tablet-device-id'
        expect(json.listen).to.equal(
            "ws://w3gram.server.com:8080/ws/#{listenerId}")
        done()

    it 'rejects a CORS routing request from an unauthorized origin', (done) ->
      @postOptions.headers['origin'] = 'https://hax.app.com'
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 403
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Unauthorized origin'
        done()

    it 'rejects a routing request missing the listener ID', (done) ->
      @postOptions.url = "#{@httpRoot}/route/"
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 404
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        done()

    it 'rejects a routing request with an invalid listener ID', (done) ->
      @postOptions.url =
          "#{@httpRoot}/route/#{@app.listenerId('tablet-device-id')}-invalid"
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 400
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Invalid listener ID'
        done()

    it '500s on AppCachge#decodeListenerId errors', (done) ->
      @sandbox.stub(@appCache, 'decodeListenerId').callsArgWith 1, new Error()
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 500
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Database error'
        done()
