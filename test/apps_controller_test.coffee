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

  describe 'GET /mak', ->
    it 'returns the MAK if there are no apps', (done) ->
      request.get "#{@httpRoot}/mak", (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 200
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        w3gram_test_config.appList().getMak (error, mak) =>
          expect(error).not.to.be.ok
          expect(json.mak).to.equal mak
          done()

    it '403s if there are registered apps', (done) ->
      @appList.create name: 'mak-403-test', (error, app) =>
        request.get "#{@httpRoot}/mak", (error, response, body) =>
          expect(error).not.to.be.ok
          expect(response.statusCode).to.equal 403
          expect(response.headers['access-control-allow-origin']).to.equal '*'
          expect(body).to.equal ''
          done()

    it '500s on AppCache#hasApps errors', (done) ->
      @sandbox.stub(@appCache, 'hasApps').callsArgWith 0, new Error()
      request.get "#{@httpRoot}/mak", (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 500
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Database error'
        done()

    it '500s on AppCache#getMak errors', (done) ->
      @sandbox.stub(@appCache, 'getMak').callsArgWith 0, new Error()
      request.get "#{@httpRoot}/mak", (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 500
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Database error'
        done()

  describe 'OPTIONS /apps', ->
    it 'returns a CORS-compliant response', (done) ->
      requestOptions =
        url: "#{@httpRoot}/apps"
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

  describe 'POST /apps', ->
    beforeEach (done) ->
      @appCache.getMak (error, mak) =>
        expect(error).to.equal null
        @mak = mak
        @postOptions =
          url: "#{@httpRoot}/apps",
          headers:
            'content-type': 'application/json; charset=utf-8'
          body: JSON.stringify(
            mak: @mak
            app: { name: 'Post App Name', origin: 'postapp.com:8080' })
        done()

    it 'creates an app if all params match', (done) ->
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 201
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.name).to.equal 'Post App Name'
        expect(json.origin).to.equal 'postapp.com:8080'
        expect(json.key).to.be.a 'string'
        expect(json.key.length).to.be.at.least 16
        expect(json.secret).to.be.a 'string'
        expect(json.secret.length).to.be.at.least 32
        done()

    it '403s if mak is missing', (done) ->
      @postOptions.body = JSON.stringify(
        app: { name: 'Post App Name', origin: 'postapp.com:8080' })
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 403
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(body).to.equal ''
        done()

    it '403s if mak is wrong', (done) ->
      @postOptions.body = JSON.stringify(
        mak: @mak + '-but-wrong'
        app: { name: 'Post App Name', origin: 'postapp.com:8080' })
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 403
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(body).to.equal ''
        done()

    it '400s if app is missing', (done) ->
      @postOptions.body = JSON.stringify mak: @mak
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 400
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Missing app property'
        done()

    it '400s if app.name is missing', (done) ->
      @postOptions.body = JSON.stringify(
        mak: @mak
        app: { origin: 'postapp.com:8080' })
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 400
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Missing app property'
        done()

    it '400s if app.origin is missing', (done) ->
      @postOptions.body = JSON.stringify(
        mak: @mak
        app: { name: 'Post App Name' })
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 400
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Missing app property'
        done()

    it '500s on AppCache#getMak errors', (done) ->
      @sandbox.stub(@appCache, 'getMak').callsArgWith 0, new Error()
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 500
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Database error'
        done()

    it '500s on AppList#create errors', (done) ->
      @sandbox.stub(@appList, 'create').callsArgWith 1, new Error()
      request.post @postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 500
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(response.headers['content-type']).to.equal(
            'application/json; charset=utf-8')
        json = JSON.parse body
        expect(json.error).to.equal 'Database error'
        done()

