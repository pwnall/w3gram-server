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
    @appCache.reset()
    @appList.setup (error) ->
      if error
        console.error error
        process.exit 1
      done()

  afterEach (done) ->
    sinon.restore
    @appCache.reset()
    @appList.teardown (error) ->
      if error
        console.error error
        process.exit 1
      done()

  describe 'OPTIONS /register', ->
    it 'returns a CORS-compliant response', (done) ->
      requestOptions =
        url: "#{@httpRoot}/register"
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

  describe 'POST /register', ->
    beforeEach (done) ->
      appOptions =
        name: 'routing test app', origin: 'https://test.app.com'
      @appList.create appOptions, (error, app) =>
        expect(error).to.equal null
        @app = app
        @postOptions =
          url: "#{@httpRoot}/register"
          headers:
            'content-type': 'application/json; charset=utf-8'
            'host': 'w3gram.server.com:8080'
          body: JSON.stringify(
            app: @app.key
            device: 'tablet-device-id'
            token: @app.token('tablet-device-id'))
        done()

    it 'processes a correct registration', (done) ->
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 200
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        listenerId = @app.listenerId 'tablet-device-id'
        receiverId = @app.receiverId 'tablet-device-id'
        expect(json.push).to.equal(
            "http://w3gram.server.com:8080/push/#{receiverId}")
        expect(json.route).to.equal(
            "http://w3gram.server.com:8080/route/#{listenerId}")
        done()

    it 'processes a correct CORS registration', (done) ->
      @postOptions.headers['origin'] = 'https://test.app.com'
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 200
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        listenerId = @app.listenerId 'tablet-device-id'
        receiverId = @app.receiverId 'tablet-device-id'
        expect(json.push).to.equal(
            "http://w3gram.server.com:8080/push/#{receiverId}")
        expect(json.route).to.equal(
            "http://w3gram.server.com:8080/route/#{listenerId}")
        done()

    it 'rejects a CORS registration from an unauthorized origin', (done) ->
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

    it 'rejects a registration missing the API key', (done) ->
      @postOptions.body = JSON.stringify(
          device: 'tablet-device-id', token: @app.token('tablet-device-id'))
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 400
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Missing API key'
        done()

    it 'rejects a registration missing the device ID', (done) ->
      @postOptions.body = JSON.stringify(
          app: @app.key, token: @app.token('tablet-device-id'))
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 400
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Missing device ID'
        done()

    it 'rejects a registration missing the token', (done) ->
      @postOptions.body = JSON.stringify(
          app: @app.key, device: 'tablet-device-id')
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 400
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Missing token'
        done()

    it 'rejects a registration with an invalid API key', (done) ->
      @postOptions.body = JSON.stringify(
            app: @app.key + '-but-not-really'
            device: 'tablet-device-id'
            token: @app.token('tablet-device-id'))
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 400
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Invalid API key'
        done()

    it 'rejects a registration with an invalid token', (done) ->
      @postOptions.body = JSON.stringify(
            app: @app.key
            device: 'tablet-device-id'
            token: @app.token('tablet-device-id') + '-but-not-really')
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 400
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Invalid token'
        done()


    it '500s on AppCachge#getAppByKey errors', (done) ->
      sinon.stub(@appCache, 'getAppByKey').callsArgWith 1, new Error()
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 500
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Database error'
        done()
