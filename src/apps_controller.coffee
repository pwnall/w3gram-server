# Handles requests for apps lists.
class AppsController
  # Adds this controller to an Express application.
  #
  # @param {express} app the Express application that this controller will be
  #   mounted in
  # @param {AppList} appList the list of applications allowed to access this
  #   server
  # @param {AppCache} appCache the cache for appList
  constructor: (app, appList, appCache) ->
    @_app = app
    @_appList = appList
    @_appCache = appCache

    @_app.get '/mak', (request, response) =>
      @_appCache.hasApps (error, hasApps) =>
        if error isnt null
          response.status(500).json error: 'Database error'
          return
        if hasApps
          response.status(403).end()
          return
        @_appCache.getMak (error, mak) ->
          if error is null
            response.json mak: mak
          else
            response.status(500).json error: 'Database error'
          return
        return
      return

    @_app.post '/apps', (request, response) =>
      @_appCache.getMak (error, mak) =>
        if error isnt null
          response.status(500).json error: 'Database error'
          return
        if request.body.mak isnt mak
          response.status(403).end()
          return
        appParams = request.body.app
        unless appParams and appParams.name and appParams.origin
          response.status(400).json error: 'Missing app property'
          return
        @_appList.create appParams, (error, app) =>
          if error isnt null
            if error.httpStatus
              response.status(error.httpStatus).json error: error.message
            else
              response.status(500).json error: 'Database error'
            return
          response.status(201).json app.json()
        return
      return
    return


module.exports = AppsController
