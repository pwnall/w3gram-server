bodyParser = require 'body-parser'
cors = require 'cors'
express = require 'express'
http = require 'http'
ws = require 'ws'

AppsController = require './apps_controller.coffee'
PushController = require './push_controller.coffee'
RegistrationController = require './registration_controller.coffee'
RoutingController = require './routing_controller.coffee'

# Ties together all the controllers.
class Server
  # Sets up the Web and WebSocket servers.
  #
  # @param {AppList} appList the list of applications allowed to use this
  #   server
  # @param {AppCache} appCache a cache for appList
  # @param {SwitchBox} switchBox
  # @param {Object} options server configuration
  # @option options {String} port the port to bind to
  constructor: (appList, appCache, switchBox, options) ->
    @_port = parseInt(options.port) or 0
    @_address = null

    @_switchBox = switchBox

    @_app = express()
    @_app.enable 'case sensitive routing'
    @_app.enable 'strict routing'
    @_app.enable 'trust proxy'
    @_app.disable 'x-powered-by'
    @_app.use cors methods: ['POST'], maxAge: 31536000
    @_app.use bodyParser.json(
        strict: true, type: 'application/json', limit: 65536)

    # The controllers are ordered by the expected relative frequency of
    # received requests.
    new PushController @_app, appCache, switchBox
    new RegistrationController @_app, appCache
    new RoutingController @_app, appCache
    new AppsController @_app, appList, appCache

    @_http = http.createServer @_app
    @_ws = new ws.Server(
      server: @_http,
      verifyClient: (info, callback) ->
        Server.WsConnection.verifyClient appCache, info, callback
    )
    @_ws.on 'connection', @_onWsConnection.bind(@)

  # Starts listening to the server's socket.
  #
  # @param {function()} callback called when the server is ready to accept
  #   incoming connections
  # @return undefined
  listen: (callback) ->
    if @_address
      throw new Error 'Already listening'
    @_http.listen @_port, =>
      @_address = @_http.address()
      callback()
    return

  # Stops listening to this server's socket.
  #
  # @param {function()} callback called after the server closes its listen
  #   socket
  # @return undefined
  close: (callback) ->
    unless @_address
      throw new Error 'Not listening'
    @_address = null
    @_ws.close (wsError) =>
      @_http.close (httpError)->
        callback wsError or httpError
    return

  # This server's HTTP URL.
  #
  # @return {String} the URL to send HTTP requests to; null if the server
  #   didn't start listening
  httpUrl: (callback) ->
    return null unless @_address
    "http://localhost:#{@_address.port}"

  # This server's WebSockets URL.
  #
  # @return {String} the URL to connect WebSockets to; null if the server
  #   didn't start listening
  wsUrl: (callback) ->
    return null unless @_address
    "ws://localhost:#{@_address.port}"

  # Developer-friendly listen address.
  #
  # This is intended to be displayed in "Listening to ..." messages.
  #
  # @return {String} the listening socket's address, formatted as host:port
  listenAddress: ->
    return null unless @_address
    "#{@_address.address}:#{@_address.port}"

  # Called when a WebSocket connection is established.
  #
  # @param {ws.WebSocket} webSocket the WebSocket connection
  # @return undefined
  _onWsConnection: (webSocket) ->
    new Server.WsConnection @_switchBox, webSocket

Server.WsConnection = require './ws_connection.coffee'


module.exports = Server
