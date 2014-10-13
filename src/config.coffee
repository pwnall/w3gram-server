AppCache = require './app_cache.coffee'
AppList = require './app_list.coffee'
Server = require './server.coffee'
SwitchBox = require './switch_box.coffee'

# Assembles the server's components based on a configuration.
class Config
  # Loads a JSON configuration.
  #
  # @param {Object} json a JSON configuration dictionary
  # @option options {String} pg_database URL to the database backing the
  #   application list
  # @option options {String} pg_pool_min minimum number of connections in the
  #   database connection pool (2 by default)
  # @option options {String} pg_pool_max maximum number of connections in the
  #   database connection pool (10 by default)
  constructor: (json) ->
    @_config =
      appList:
        databaseUrl: json.pg_database || process.env['DATABASE_URL']
        poolMin: json.pg_pool_min
        poolMax: json.pg_pool_max
      server:
        port: json.port

  # @return {Server} the server built from this configuration
  server: ->
    @_server ||= new Server(
        @appList(), @appCache(), @switchBox(), @_config.server)

  # @return {AppList} the application list built from this configuration
  appList: ->
    @_appList ||= new AppList @_config.appList

  # @return {AppCache} a cache for this configuration's application list
  appCache: ->
    @_appCache ||= new AppCache @appList()

  # @return {SwitchBox} a SwitchBox built from this configuration
  switchBox: ->
    @_switchBox ||= new SwitchBox()

module.exports = Config
