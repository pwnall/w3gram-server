# Handles notification push requests.
class PushController
  # Adds this controller to an Express application.
  #
  # @param {express} app the Express application that this controller will be
  #   mounted in
  # @param {AppCache} appCache the cache for the list of applications allowed
  #   to access this server
  # @param {SwitchBox} switchBox routes push notifcations to the receivers'
  #   WebSocket connections
  constructor: (app, appCache, switchBox) ->
    @_app = app
    @_appCache = appCache
    @_switchBox = switchBox

    @_app.post '/push', (request, response) =>
      receiverId = request.body.receiver
      message = request.body.message
      if typeof receiverId isnt 'string'
        response.status(400).json error: 'Missing receiver ID'
        return
      if typeof message isnt 'object'
        response.status(400).json error: 'Missing message object'
        return

      @_appCache.decodeReceiverId receiverId, (error, app, hashKey) =>
        if error isnt null
          response.status(500).json error: 'Database error'
          return
        if app is null
          response.status(400).json error: 'Invalid receiver ID'
          return
        unless app.acceptsOrigin request.headers['origin']
          response.status(403).json error: 'Unauthorized origin'
          return

        @_switchBox.pushNotification hashKey, message, (error) ->
          if error isnt null
            response.status(500).json error: 'Switchbox error'
            return
          response.status(204).end()
          return
        return
      return
    return


module.exports = PushController

