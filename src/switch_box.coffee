# Routes push notifications to the receivers' WebSocket connections.
class SwitchBox
  constructor: ->
    @_hash = []

  # Called when a new WebSocket connection is made.
  #
  # @param {WsConnection} wsConnection the new connection
  # @return undefined
  addConnection: (wsConnection) ->
    hashKey = wsConnection.hashKey()
    if hashKey of @_hash
      oldConnection = @_hash[hashKey]
      oldConnection.closeOnDuplicateConnection()
    @_hash[hashKey] = wsConnection
    return

  # Called when a WebSocket connection is closed.
  #
  # @param {WsConnection} wsConnection the closed connection
  # @return undefined
  removeConnection: (wsConnection) ->
    hashKey = wsConnection.hashKey()
    if @_hash[hashKey] is wsConnection
      delete @_hash[hashKey]
    return

  # Routes a notification to the appropriate WebSocket connection.
  #
  # @param {String} hashKey the connection's hash key, as provided by
  #   {AppCache.decodeReceiverId}
  # @param {Object} the JSON notification body
  # @return undefined
  pushNotification: (hashKey, data, callback) ->
    wsConnection = @_hash[hashKey]
    unless wsConnection
      callback null
      return

    wsConnection.pushNotification data
    callback null
    return

module.exports = SwitchBox
