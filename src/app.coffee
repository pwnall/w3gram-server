crypto = require 'crypto'

AppList = {}

# Metadata about a single application that is allowed to use this server.
class AppList.App
  # @param {Object} fields initial values
  # @option fields {Number} id private ID, primary key
  # @option fields {String} key public application ID
  # @option fields {String{ idKey HMAC key used by receiver IDs
  # @option fields {String} secret token used to authenticate app requests to
  #   the API
  # @option fields {String} origin allowed CORS Origin header value
  # @option fields {String} name user-friendly name for the application
  constructor: (fields) ->
    for own key, value of fields
      @[key] = value

  # @return {Object} JSON-compatible object representing the app fields
  json: ->
    { key: @key, secret: @secret, origin: @origin, name: @name }

  # Checks if requests from a given origin should be serviced.
  #
  # @param {String} origin the value of the Origin header in a request; null if
  #   the request does not include any header
  # @return {Boolean} true / false
  acceptsOrigin: (origin) ->
    # Origin-less requests come from server apps. They can be authenticated
    # using other means (e.g., the application secret) if that is desirable.
    return true unless origin

    # * means accept all origins.
    if @origin is '*' then true else @origin is origin

  # Computes the token for a device.
  #
  # @param {String} deviceId the device's ID
  # @return {String} the token
  token: (deviceId) ->
    return null unless AppList.App.isValidDeviceId deviceId
    AppList.App._hmac @secret, "device-id|#{deviceId}"

  # Creates a receiver ID for a device ID.
  #
  # @param {String} deviceId the device ID to create a receiver ID for
  # @return {String} the receiver ID, or null if the argument is an invalid
  #   device ID
  receiverId: (deviceId) ->
    return null unless AppList.App.isValidDeviceId deviceId
    hmac = @receiverIdHmac deviceId
    "#{@id}.#{deviceId}.#{hmac}"

  # The HMAC included in a receiver ID.
  #
  # @param {String} deviceId the device ID that the receiver ID is used for
  # @return {String} the HMAC in the receiver ID, or null if the argument is an
  #   invalid device ID
  receiverIdHmac: (deviceId) ->
    return null unless AppList.App.isValidDeviceId deviceId
    AppList.App._hmac @idKey, "receiver-id|#{@id}|#{deviceId}"

  # Checks if a string is a valid device ID.
  #
  # @param {String} deviceId the string to be checked
  # @return {Boolean} true if the argument is a valid device ID, false
  #   otherwise
  @isValidDeviceId: (deviceId) ->
    return false unless deviceId.length <= 64
    /^[A-Za-z0-9_\-]+$/.test deviceId

  # Computes a URL-safe base64-encoded SHA-256 HMAC.
  #
  # @param {String} key the HMAC key
  # @param {String} data the string to be HMAC-ed
  # @return {String} the HMAC value
  #
  # @see http://csrc.nist.gov/groups/STM/cavp/documents/shs/sha256-384-512.pdf
  #   SHA-256
  # @see http://tools.ietf.org/html/rfc2104 HMAC
  # @see http://tools.ietf.org/html/rfc4648#section-5 URL-safe base64
  @_hmac: (key, data) ->
    crypto.createHmac('sha256', key).update(data).digest('base64').
        replace(/\+/g, '-').replace(/\//g, '_').replace(/\=/g, '')


module.exports = AppList.App
