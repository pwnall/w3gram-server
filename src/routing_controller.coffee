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

    @_app.post '/route/:listener', (request, response) =>
      listenerId = request.params.listener
      if typeof listenerId isnt 'string'
        response.status(400).json error: 'Missing listener ID'
        return

      @_appCache.decodeListenerId listenerId, (error, app, hashKey) =>
        if error isnt null
          response.status(500).json error: 'Database error'
          return
        if app is null
          response.status(400).json error: 'Invalid listener ID'
          return
        unless app.acceptsOrigin request.headers['origin']
          response.status(403).json error: 'Unauthorized origin'
          return

        host = request.headers['host']
        wsProtocol = if request.secure then 'wss' else 'ws'
        wsUrl = wsProtocol + '://' + host + '/ws/' + listenerId
        response.status(200).json listen: wsUrl
        return
      return
    return


module.exports = RoutingController
