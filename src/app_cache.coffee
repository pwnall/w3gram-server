# Caches the information in an AppList, to avoid SQL database queries.
class AppCache
  # Creates a new cache.
  #
  # @param {AppList} appList the AppList to be cached
  constructor: (appList) ->
    @_appList = appList
    @reset()

  # Resets the information in the cache.
  reset: ->
    @_appsByKey = {}
    @_appsById = {}
    @_hasAppsForSure = false
    @_mak = null

  # Checks if the AppList is empty.
  #
  # This check is used to decides if the server should display its MAK.
  #
  # @param {function(Error, boolean)} callback called with true if the AppList
  #  is not empty, and false if no apps have been registered
  # @return undefined
  hasApps: (callback) ->
    if @_hasAppsForSure
      callback null, true
      return
    @_reloadApps (error) =>
      if error is null
        callback null, @_hasAppsForSure
      else
        callback error
      return
    return

  # Retrieves the MAK.
  #
  # The MAK is cached to avoid repeated database queries.
  #
  # @param {function(Error, String)} callback called when the MAK is retrieved
  # @return undefined
  getMak: (callback) ->
    if @_mak isnt null
      callback null, @_mak
      return
    @_appList.getMak (error, mak) =>
      if error is null
        @_mak = mak
        callback null, @_mak
      else
        callback error
      return
    return

  # Retrieves an app based on its API key.
  #
  # @param {String} key the app's API key
  # @param {function(Error, AppList.App)} callback called when the app is read;
  #   receives null if no app exists with the given key
  # @return undefined
  getAppByKey: (key, callback) ->
    if key of @_appsByKey
      callback null, @_appsByKey[key]
      return
    @_appList.findByKey key, (error, app) =>
      @_getAppCallback error, app, callback
      return
    return

  # Retrieves an app based on its API key.
  #
  # @param {Number} id the app's database ID
  # @param {function(Error, AppList.App)} callback called when the app is read;
  #   receives null if no app exists with the given key
  # @return undefined
  getAppById: (id, callback) ->
    if id of @_appsById
      callback null, @_appsById[id]
      return
    @_appList.findById id, (error, app) =>
      @_getAppCallback error, app, callback
      return
    return

  # Common callback shared by all app getters.
  #
  # @param {Error} error given to the AppList operation callback
  # @param {AppList.App} app given to the AppList operation callback
  # @param {function(Error, AppList.App)} callback called with the app returned
  #   by the AppList.App operation
  _getAppCallback: (error, app, callback) ->
    if error isnt null
      callback error
      return
    @_cacheApp app unless app is null
    callback error, app
    return

  # Decodes a receiver ID and returns a hash key used to identify the receiver.
  #
  # @param {String} receiverId the receiver ID to be decoded
  # @callback {function(Error, AppList.App, String)} callback called with the
  #   app that issued the receiver ID, and a hash key; the app and the key are
  #   null if the receiver ID is invalid (e.g., the HMAC doesn't match)
  # @return undefined
  decodeReceiverId: (receiverId, callback) ->
    components = receiverId.split '.'
    unless components.length is 3
      callback null, null, null
      return
    [idString, deviceId, hmac] = components
    id = parseInt idString
    @getAppById id, (error, app) =>
      if error isnt null
        callback error
        return
      if app is null or app.receiverIdHmac(deviceId) isnt hmac
        callback null, null, null
      else
        callback null, app, app.hashKey(deviceId)
      return
    return

  # Decodes a listener ID and returns a hash key used to identify the listener.
  #
  # @param {String} listenerId the listener ID to be decoded
  # @callback {function(Error, AppList.App, String)} callback called with the
  #   app that issued the listener ID, and a hash key; the app and the key are
  #   null if the listener ID is invalid (e.g., the HMAC doesn't match)
  # @return undefined
  decodeListenerId: (listenerId, callback) ->
    components = listenerId.split '.'
    unless components.length is 3
      callback null, null, null
      return
    [idString, deviceId, hmac] = components
    id = parseInt idString
    @getAppById id, (error, app) =>
      if error isnt null
        callback error
        return
      if app is null or app.listenerIdHmac(deviceId) isnt hmac
        callback null, null, null
      else
        callback null, app, app.hashKey(deviceId)
      return
    return

  # Reads the entire AppList and updates the cache.
  #
  # @param {function(Error)} callback called when the apps cache has been
  #   updated
  # @return undefined
  _reloadApps: (callback) ->
    @_appList.list (error, apps) =>
      if error isnt null
        callback error
        return
      for app in apps
        @_cacheApp app
      callback null
      return
    return

  # Updates the caches to include an app.
  #
  # @param {AppList.App} app the app to be added to the caches
  # @return undefined
  _cacheApp: (app) ->
    @_appsByKey[app.key] = app
    @_appsById[app.id] = app
    @_hasAppsForSure = true
    return

module.exports = AppCache
