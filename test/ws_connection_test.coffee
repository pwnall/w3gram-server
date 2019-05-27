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
    @appCache.reset()
    @appList.setup (error) =>
      if error
        console.error error
        process.exit 1
      appOptions = { name: 'ws-test-app', origin: 'https://test.app.com' }
      @appList.create appOptions, (error, app) =>
        expect(error).to.equal null
        @app = app
        @listenerId = app.listenerId 'tablet-device-id'
        @receiverId = app.receiverId 'tablet-device-id'
        @wsUrl = "#{@server.wsUrl()}/ws/#{@listenerId}"
        @wsOrigin = 'https://test.app.com'
        done()

  afterEach (done) ->
    sinon.restore()
    @appCache.reset()
    @appList.teardown (error) ->
      if error
        console.error error
        process.exit 1
      done()

  it 'accepts a valid CORS connection', (done) ->
    ws = new WebSocket @wsUrl, origin: @wsOrigin
    ws.onopen = ->
      gotHello = false
      ws.onmessage = (event) ->
        expect(gotHello).to.equal false
        gotHello = true
        expect(event.data).to.be.a 'string'
        json = JSON.parse event.data
        expect(json.type).to.equal 'hi'
        expect(json.data).to.be.a 'object'
        expect(json.data.version).to.equal 0
        ws.onclose = (event) ->
          expect(event.code).to.equal 1000
          expect(event.reason).to.equal ''
          done()
        ws.close 1000

  it '403s a CORS connection from an unauthorized origin', (done) ->
    ws = new WebSocket @wsUrl, origin: 'https://evil.app.com'
    ws.onopen = ->
      expect('Server should not accept connection').to.equal false
      done()
    ws.onerror = (error) ->
      expect(error.message).to.equal 'Unexpected server response: 403'
      ws.close()
      done()

  it '400s a connection without a listener ID', (done) ->
    ws = new WebSocket "#{@server.wsUrl()}/ws"
    ws.onopen = ->
      expect('Server should not accept connection').to.equal false
      done()
    ws.onerror = (error) ->
      expect(error.message).to.equal 'Unexpected server response: 400'
      ws.close()
      done()

  it '400s a connection with an invalid listener ID', (done) ->
    ws = new WebSocket "#{@server.wsUrl()}/ws/42.invalid.listener-id"
    ws.onopen = ->
      expect('Server should not accept connection').to.equal false
      done()
    ws.onerror = (error) ->
      expect(error.message).to.equal 'Unexpected server response: 400'
      ws.close()
      done()

  it '500s a connection on database error', (done) ->
    sinon.stub(@appCache, 'getAppById').callsArgWith 1, new Error()
    ws = new WebSocket @wsUrl
    ws.onopen = ->
      expect('Server should not accept connection').to.equal false
      done()
    ws.onerror = (error) ->
      expect(error.message).to.equal 'Unexpected server response: 500'
      ws.close()
      done()

  it 'responds with a pong to a ping request', (done) ->
    ws = new WebSocket @wsUrl, origin: @wsOrigin
    ws.onopen = ->
      ws.send JSON.stringify(type: 'ping', data: { ts: 42 })

      gotHello = false
      ws.onmessage = (event) ->
        expect(gotHello).to.equal false
        gotHello = true
        expect(event.data).to.be.a 'string'
        json = JSON.parse event.data
        expect(json.type).to.equal 'hi'
        expect(json.data).to.be.a 'object'
        expect(json.data.version).to.equal 0

        gotPong = false
        ws.onmessage = (event) ->
          expect(gotPong).to.equal false
          gotPong = true
          expect(event.data).to.be.a 'string'
          json = JSON.parse event.data
          expect(json).to.deep.equal type: 'pong', data: { ts: 42 }
          ws.close 1000
        ws.onclose = (event) ->
          expect(event.code).to.equal 1000
          expect(event.reason).to.equal ''
          expect(gotPong).to.equal true
          done()

  it 'closes with 4400 on a non-JSON request', (done) ->
    ws = new WebSocket @wsUrl, origin: @wsOrigin
    ws.onopen = ->

      gotHello = false
      ws.onmessage = (event) ->
        expect(gotHello).to.equal false
        gotHello = true
        expect(event.data).to.be.a 'string'
        json = JSON.parse event.data
        expect(json.type).to.equal 'hi'
        expect(json.data).to.be.a 'object'
        expect(json.data.version).to.equal 0

        ws.send 'derp derp derp'
        ws.onmessage = (event) ->
          expect('Server should not respond to an invalid request').to.
              equal false
          done()
        ws.onclose = (event) ->
          expect(event.code).to.equal 4400
          expect(event.reason).to.equal 'Invalid JSON request'
          done()

  it 'closes with 4404 on invalid request type', (done) ->
    ws = new WebSocket @wsUrl, origin: @wsOrigin
    ws.onopen = ->
      gotHello = false
      ws.onmessage = (event) ->
        expect(gotHello).to.equal false
        gotHello = true
        expect(event.data).to.be.a 'string'
        json = JSON.parse event.data
        expect(json.type).to.equal 'hi'
        expect(json.data).to.be.a 'object'
        expect(json.data.version).to.equal 0

        ws.send JSON.stringify(type: 'note', data: { text: 'I am the server' })
        ws.onmessage = (event) ->
          expect('Server should not respond to an invalid request').to.
              equal false
          done()
        ws.onclose = (event) ->
          expect(event.code).to.equal 4404
          expect(event.reason).to.equal 'Invalid request type'
          done()

  it 'delivers a push notification', (done) ->
    ws = new WebSocket @wsUrl, origin: @wsOrigin
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

    gotHello = false
    ws.onmessage = (event) =>
      expect(gotHello).to.equal false
      gotHello = true
      expect(event.data).to.be.a 'string'
      json = JSON.parse event.data
      expect(json.type).to.equal 'hi'
      expect(json.data).to.be.a 'object'
      expect(json.data.version).to.equal 0

      postOptions =
        url: "#{@httpRoot}/push/#{@receiverId}"
        headers:
          'content-type': 'application/json; charset=utf-8'
        body: JSON.stringify(
          message: { text: 'This is a push notification' })
      request.post postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 204
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(body).to.equal ''
        done1()

      ws.onmessage = (event) ->
        expect(gotMessage).to.equal false
        gotMessage = true
        expect(event.data).to.be.a 'string'
        json = JSON.parse event.data
        expect(json).to.deep.equal(
            type: 'note', data: { text: 'This is a push notification' })
        ws.close 1000

      ws.onclose = (event) ->
        expect(gotMessage).to.equal true
        expect(event.code).to.equal 1000
        expect(event.reason).to.equal ''
        done2()


  it 'delivers a push notification to five clients', (done) ->
    wss = [
      new WebSocket(@wsUrl, origin: @wsOrigin),
      new WebSocket(@wsUrl, origin: @wsOrigin),
      new WebSocket(@wsUrl, origin: @wsOrigin),
      new WebSocket(@wsUrl, origin: @wsOrigin),
      new WebSocket(@wsUrl, origin: @wsOrigin),
    ]
    doneFlags = [
      [false, false, false, false, false],
      [false, false, false, false, false]
    ]

    readyToPost = (i) =>
      expect(doneFlags[0][i]).to.equal false
      doneFlags[0][i] = true
      for flag in doneFlags[0]
        return if flag is false

      postOptions =
        url: "#{@httpRoot}/push/#{@receiverId}"
        headers:
          'content-type': 'application/json; charset=utf-8'
        body: JSON.stringify(
          message: { text: 'This is a push notification' })
      request.post postOptions, (error, response, body) =>
        expect(error).not.to.be.ok
        expect(response.statusCode).to.equal 204
        expect(response.headers['access-control-allow-origin']).to.equal '*'
        expect(body).to.equal ''

    done2 = (i) ->
      expect(doneFlags[1][i]).to.equal false
      doneFlags[1][i] = true
      for flag in doneFlags[1]
        return if flag is false
      done()

    for ws, i in wss
      do (ws, i) =>
        gotHello = false
        gotMessage = false
        ws.onmessage = (event) =>
          expect(gotHello).to.equal false
          gotHello = true
          expect(event.data).to.be.a 'string'
          json = JSON.parse event.data
          expect(json.type).to.equal 'hi'
          expect(json.data).to.be.a 'object'
          expect(json.data.version).to.equal 0
          readyToPost i

          ws.onmessage = (event) ->
            expect(gotMessage).to.equal false
            gotMessage = true
            expect(event.data).to.be.a 'string'
            json = JSON.parse event.data
            expect(json).to.deep.equal(
                type: 'note', data: { text: 'This is a push notification' })
            ws.close 1000

          ws.onclose = (event) ->
            expect(gotMessage).to.equal true
            expect(event.code).to.equal 1000
            expect(event.reason).to.equal ''
            done2 i
