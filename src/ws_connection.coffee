Server = {}

# Handles a WebSocket connection.
class Server.WsConnection
  # Field used by the switch box to track connections.
  switchBoxSerial: null

  # Sets up the handler for a connection.
  #
  # @param {SwitchBox} switchBox used to route push notification requests to
  #   this WebSocket connection
  # @param {ws.WebSocket} webSocket the WebSocket connection
  # @param {AppCache} appCache the cache for the list of applications that
  #   are allowed to use connections
  constructor: (switchBox, webSocket) ->
    @_switchBox = switchBox
    @_ws = webSocket

    @switchBoxSerial = null
    @_closed = false

    verifyInfo = webSocket.upgradeReq.w3gramInfo
    unless verifyInfo and @_app = verifyInfo.app and
                          @_receiverHash = verifyInfo.receiverHash
      throw new Error('Incompatible ws implementation change. ' +
                      'Please file a bug including your ws version.')

    webSocket.on 'message', @_onWsMessage.bind(@)
    webSocket.on 'error', @_onWsError.bind(@)
    webSocket.on 'close', @_onWsClose.bind(@)
    @_switchBox.addConnection @
    @_ws.send JSON.stringify(type: 'hi', data: { version: 0 })

    return

  # Decides whether to accept a WebSocket connection.
  #
  # @param {AppCache} appCache the cache for the list of applications that are
  #   allowed to use connections
  # @param {Object} info the connection info supplied by ws.Server
  # @param {function(Boolean, Number)} callback called with true/false,
  #   and an HTTP error code
  @verifyClient: (appCache, info, callback) ->
    upgradeRequest = info.req
    url = upgradeRequest.url
    unless url.substring(0, 4) is '/ws/'
      callback false, 400
      return
    listenerId = url.substring 4
    appCache.decodeListenerId listenerId, (error, app, receiverHash) ->
      if error
        callback false, 500
        return
      if app is null
        callback false, 400
        return
      if app.acceptsOrigin upgradeRequest.headers['origin']
        upgradeRequest.w3gramInfo = { app: app, receiverHash: receiverHash }
        callback true
      else
        callback false, 403
      return
    return

  # Called when a new connection is established using the same device ID.
  closeOnDuplicateConnection: ->
    @_close 4409, 'Device reconnected'
    return

  # Pushes a notification to the client.
  #
  # @param {Object} data JSON notification body
  pushNotification: (data) ->
    return if @_closed
    @_ws.send JSON.stringify(type: 'note', data: data)
    return

  # @return {String} the hash key for the connection's receiver, as produced by
  #   {AppCache#decodeListenerId}
  receiverHash: ->
    @_receiverHash

  # Closes the underlying WebSocket.
  _close: (code, reason) ->
    return if @_closed
    @_closed = true
    @_switchBox.removeConnection @
    @_ws.close code, reason
    return

  # Called when a message is received from a WebSocket.
  #
  # @param {String} data the message data
  # @param {Object} flags an object with the property 'binary'
  _onWsMessage: (data, flags) ->
    return if @_closed

    try
      json = JSON.parse data
    catch jsonError
      @_close 4400, 'Invalid JSON request'
      return

    if json.type is 'ping'
      @_ws.send JSON.stringify(type: 'pong', data: json.data)
      return

    @_close 4404, 'Invalid request type'
    return

  # Called when a WebSocket connection is closed.
  #
  # @param {ws.WebSocket} webSocket the closed WebSocket connection
  # @param {Number} code the reason code sent during the close
  # @param {String} message the message sent along with the code
  # @return undefined
  _onWsClose: (code, message) ->
    @_close 1000, null
    return

  # Called when a WebSocket connection errors out.
  #
  # @param {ws.WebSocket} webSocket the WebSocket connection that errored out
  # @param {} error the error
  # @return undefined
  _onWsError: (error) ->
    @_close 4500, null
    return


module.exports = Server.WsConnection
