# Handles the routing process.
class RoutingController
  # Adds this controller to an Express application.
  #
  # @param {express} app the Express application that this controller will be
  #   mounted in
  # @param {AppCache} appCache the cache for the list of applications allowed
  #   to access this server
  constructor: (app, appCache) ->
    @_app = app
    @_appCache = appCache

    @_app.post '/route', (request, response) =>
      appKey = request.body.app
      deviceId = request.body.device
      receiverId = request.body.receiver
      token = request.body.token
      if typeof appKey isnt 'string'
        response.status(400).json error: 'Missing API key'
        return
      if typeof deviceId isnt 'string'
        response.status(400).json error: 'Missing device ID'
        return
      if typeof receiverId isnt 'string'
        response.status(400).json error: 'Missing receiver ID'
        return
      if typeof token isnt 'string'
        response.status(400).json error: 'Missing token'
        return

      @_appCache.getAppByKey appKey, (error, app) =>
        if error isnt null
          response.status(500).json error: 'Database error'
          return
        if app is null
          response.status(400).json error: 'Invalid API key'
          return
        unless app.acceptsOrigin request.headers['origin']
          response.status(403).json error: 'Unauthorized origin'
          return
        if token isnt app.token(deviceId)
          response.status(400).json error: 'Invalid token'
          return
        if receiverId isnt app.receiverId(deviceId)
          response.status(410).json error: 'Invalid or outdated receiver ID'
          return

        listenerId = app.listenerId deviceId
        host = request.headers['host']
        pushUrl = request.protocol + '://' + host + '/push'
        wsProtocol = if request.secure then 'wss' else 'ws'
        wsUrl = wsProtocol + '://' + host + '/ws/' + listenerId
        response.status(200).json listen: wsUrl
        return
      return
    return


module.exports = RoutingController
