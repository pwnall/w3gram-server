request = require 'request'
sinon = require 'sinon'

WebSocket = require('ws')

describe 'WebSockets server', ->
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
    @appList.setup (error) =>
      if error
        console.error error
        process.exit 1
      appOptions = { name: 'ws-test-app', origin: 'https://test.app.com' }
      @appList.create appOptions, (error, app) =>
        expect(error).to.equal null
        @app = app
        @receiverId = app.receiverId 'tablet-device-id'
        @wsUrl = "#{@server.wsUrl()}/ws/#{@receiverId}"
        @wsHeaders = { origin: 'https://test.app.com' }
        done()

  afterEach (done) ->
    @sandbox.restore()
    @appCache.reset()
    @appList.teardown (error) ->
      if error
        console.error error
        process.exit 1
      done()

  it 'accepts a valid CORS connection', (done) ->
    ws = new WebSocket @wsUrl, headers: @wsHeaders
    ws.on 'open', ->
      ws.close 1000
      ws.on 'close', (code, data) ->
        expect(code).to.equal 1000
        expect(data).to.equal ''
        done()

  it '403s a CORS connection from an unauthorized origin', (done) ->
    ws = new WebSocket @wsUrl, headers: { origin: 'https://evil.app.com' }
    ws.on 'open', ->
      expect('Server should not accept connection').to.equal false
      done()
    ws.on 'error', (error) ->
      expect(error).to.be.an 'object'
      expect(error.message).to.equal 'unexpected server response (403)'
      ws.close()
      done()

  it '400s a connection without a receiver ID', (done) ->
    ws = new WebSocket "#{@server.wsUrl()}/ws"
    ws.on 'open', ->
      expect('Server should not accept connection').to.equal false
      done()
    ws.on 'error', (error) ->
      expect(error).to.be.an 'object'
      expect(error.message).to.equal 'unexpected server response (400)'
      ws.close()
      done()

  it '400s a connection with an invalid receiver ID', (done) ->
    ws = new WebSocket "#{@server.wsUrl()}/ws/42.invalid.receiver-id"
    ws.on 'open', ->
      expect('Server should not accept connection').to.equal false
      done()
    ws.on 'error', (error) ->
      expect(error).to.be.an 'object'
      expect(error.message).to.equal 'unexpected server response (400)'
      ws.close()
      done()

  it '500s a connection on database error', (done) ->
    @sandbox.stub(@appCache, 'getAppById').callsArgWith 1, new Error()
    ws = new WebSocket @wsUrl
    ws.on 'open', ->
      expect('Server should not accept connection').to.equal false
      done()
    ws.on 'error', (error) ->
      expect(error).to.be.an 'object'
      expect(error.message).to.equal 'unexpected server response (500)'
      ws.close()
      done()

  it 'responds with a pong to a ping request', (done) ->
    ws = new WebSocket @wsUrl, headers: @wsHeaders
    gotPong = false
    ws.on 'open', ->
      ws.send JSON.stringify(type: 'ping', data: { ts: 42 })
    ws.on 'message', (data, flags) ->
      expect(gotPong).to.equal false
      gotPong = true
      expect(data).to.be.a 'string'
      expect(flags.binary).not.to.be.ok
      json = JSON.parse data
      expect(json).to.deep.equal type: 'pong', data: { ts: 42 }
      ws.close 1000
    ws.on 'close', (code, data) ->
      expect(code).to.equal 1000
      expect(data).to.equal ''
      expect(gotPong).to.equal true
      done()

  it 'closes with 4400 on a non-JSON request', (done) ->
    ws = new WebSocket @wsUrl, headers: @wsHeaders
    ws.on 'open', ->
      ws.send 'derp derp derp'
    ws.on 'message', (data, flags) ->
      expect('Server should not respond to an invalid request').to.equal false
      done()
    ws.on 'close', (code, data) ->
      expect(code).to.equal 4400
      expect(data).to.equal 'Invalid JSON request'
      done()

  it 'closes with 4404 on invalid request type', (done) ->
    ws = new WebSocket @wsUrl, headers: @wsHeaders
    ws.on 'open', ->
      ws.send JSON.stringify(type: 'note', data: { text: 'I am the server' })
    ws.on 'message', (data, flags) ->
      expect('Server should not respond to an invalid request').to.equal false
      done()
    ws.on 'close', (code, data) ->
      expect(code).to.equal 4404
      expect(data).to.equal 'Invalid request type'
      done()

  it 'closes with 4409 on new device connection', (done) ->
    ws = new WebSocket @wsUrl, headers: @wsHeaders
    gotPong = false
    ws.on 'open', =>
      ws2 = new WebSocket @wsUrl, headers: @wsHeaders
      gotWsClose = false
      ws.on 'close', (code, data) ->
        gotWsClose = true
        expect(code).to.equal 4409
        expect(data).to.equal 'Device reconnected'
        ws2.close 1000
      ws2.on 'close', (code, data) ->
        expect(gotWsClose).to.equal true
        done()

  it 'delivers a push notification', (done) ->
    ws = new WebSocket @wsUrl, headers: @wsHeaders
    gotMessage = false
    doneFlags = [false, false]
    done1 = ->
      expect(doneFlags[0]).to.equal false
      doneFlags[0] = true
      done() if doneFlags[1]
    done2 = ->
      expect(doneFlags[1]).to.equal false
      doneFlags[1] = true
      done() if doneFlags[0]

    ws.on 'open', =>
      postOptions =
        url: "#{@httpRoot}/push"
        headers:
          'content-type': 'application/json; charset=utf-8'
        body: JSON.stringify(
          receiver: @receiverId
          message: { text: 'This is a push notification' })
      request.post postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 204
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(body).to.equal ''
        done1()

    ws.on 'message', (data, flags) ->
      expect(gotMessage).to.equal false
      gotMessage = true
      expect(data).to.be.a 'string'
      expect(flags.binary).not.to.be.ok
      json = JSON.parse data
      expect(json).to.deep.equal(
          type: 'note', data: { text: 'This is a push notification' })
      ws.close 1000

    ws.on 'close', (code, data) ->
      expect(gotMessage).to.equal true
      expect(code).to.equal 1000
      done2()
