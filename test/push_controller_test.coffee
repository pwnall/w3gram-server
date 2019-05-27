request = require 'request'
sinon = require 'sinon'

describe 'HTTP server', ->
  before (done) ->
    @server = w3gram_test_config.server()
    @appCache = w3gram_test_config.appCache()
    @appList = w3gram_test_config.appList()
    @switchBox = w3gram_test_config.switchBox()

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
    sinon.restore()
    @appCache.reset()
    @appList.teardown (error) ->
      if error
        console.error error
        process.exit 1
      done()

  beforeEach (done) ->
    appOptions =
      name: 'push test app', origin: 'https://test.app.com'
    @appList.create appOptions, (error, app) =>
      expect(error).to.equal null
      @app = app
      done()


  describe 'OPTIONS /push', ->
    it 'returns a CORS-compliant response', (done) ->
      requestOptions =
        url: "#{@httpRoot}/push/#{@app.receiverId('tablet-device-id')}"
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

  describe 'POST /push', ->
    beforeEach ->
      @postOptions =
        url: "#{@httpRoot}/push/#{@app.receiverId('tablet-device-id')}"
        headers:
          'content-type': 'application/json; charset=utf-8'
        body: JSON.stringify(
          message: { text: 'This is a push notification' })

    it 'accepts a correct push request', (done) ->
      pushNotificationSpy = sinon.spy @switchBox, 'pushNotification'
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 204
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(body).to.equal ''
        expect(pushNotificationSpy).to.have.callCount 1
        done()

    it 'accepts a correct CORS push request', (done) ->
      pushNotificationSpy = sinon.spy @switchBox, 'pushNotification'
      @postOptions.headers['origin'] = 'https://test.app.com'
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 204
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(body).to.equal ''
        expect(pushNotificationSpy).to.have.callCount 1
        done()

    it 'rejects a CORS push request from an unauthorized origin', (done) ->
      pushNotificationSpy = sinon.spy @switchBox, 'pushNotification'
      @postOptions.headers['origin'] = 'https://hax.app.com'
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 403
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Unauthorized origin'
        expect(pushNotificationSpy).to.have.callCount 0
        done()

    it 'rejects a push request missing the receiver ID', (done) ->
      @postOptions.url = "#{@httpRoot}/push/"
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 404
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        done()

    it 'rejects a push request missing the message', (done) ->
      @postOptions.body = JSON.stringify({})
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 400
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Missing message object'
        done()

    it 'rejects a push request with an invalid receiver ID', (done) ->
      @postOptions.url = "#{@httpRoot}/push/invalid.receiver"
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 400
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Invalid receiver ID'
        done()

    it '500s on AppCachge#decodeReceiverId errors', (done) ->
      sinon.stub(@appCache, 'decodeReceiverId').callsArgWith 1, new Error()
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 500
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Database error'
        done()
