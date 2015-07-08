# Routes push notifications to the receivers' WebSocket connections.
class SwitchBox
  # Creates a switch box with no connections.
  constructor: ->
    @_hash = []
    @_nextSerial = 0

  # Called when a new WebSocket connection is made.
  #
  # @param {WsConnection} wsConnection the new connection
  # @return undefined
  addConnection: (wsConnection) ->
    receiverHash = wsConnection.receiverHash()

    if wsConnection.switchBoxSerial isnt null
      throw new Error("Connection already added to a SwitchBox")

    serial = @_nextSerial
    @_nextSerial += 1
    wsConnection.switchBoxSerial = serial

    receivers = @_hash[receiverHash] ||= { length: 0 }
    receivers[serial] = wsConnection
    receivers.length += 1
    return

  # Called when a WebSocket connection is closed.
  #
  # @param {WsConnection} wsConnection the closed connection
  # @return undefined
  removeConnection: (wsConnection) ->
    receiverHash = wsConnection.receiverHash()
    receivers = @_hash[receiverHash]

    serial = wsConnection.switchBoxSerial
    return if serial is null
    return unless serial of receivers
    wsConnection.switchBoxSerial = null

    delete receivers[serial]
    receivers.length -= 1
    if receivers.length is 0
      delete @_hash[receiverHash]
    return

  # Routes a notification to the appropriate WebSocket connection.
  #
  # @param {String} receiverHash the connection's hash key, as provided by
  #   {AppCache.decodeReceiverId}
  # @param {Object} the JSON notification body
  # @return undefined
  pushNotification: (receiverHash, data, callback) ->
    unless receivers = @_hash[receiverHash]
      callback null
      return

    for serial, wsConnection of receivers
      continue if serial is 'length'
      wsConnection.pushNotification data

    callback null
    return

module.exports = SwitchBox
