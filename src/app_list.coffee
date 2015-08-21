anydb = require 'any-db'
async = require 'async'
crypto = require 'crypto'

# Manages the metadata about applications that are allowed to use this server.
#
# The metadata is stored in a PostgreSQL database.
class AppList
  # Create a PostgreSQL-backed app list.
  #
  # @param {Object} options options
  # @option options {String} databaseUrl a PostgreSQL connection URL
  # @option options {Number} poolMin minimum number of database connections
  # @option options {Number} poolMax maximum number of database connections
  constructor: (options) ->
    @_url = options.databaseUrl
    @_poolMin = parseInt(options.poolMin || '2')
    @_poolMax = parseInt(options.poolMax || '10')
    @_pool = anydb.createPool @_url, @_poolMin, @_poolMax

  # Creates an app.
  #
  # @param {Object} options app properties
  # @option options {String} name user-friendly application identifier
  # @option options {String} origin restrict browser WebSocket connections to
  #   the given origin; use '*' (the default value) to allow any origin
  # @param {function(Error, AppList.App)} callback called with the new app
  # @return undefined
  create: (options, callback) ->
    origin = options.origin || '*'
    name = options.name || 'unnamed'
    async.map [12, 32, 32], AppList._urlSafeRandom, (error, values) =>
      if error
        callback error
        return
      [key, idKey, secret] = values
      @_pool.query 'INSERT INTO apps (id,key,idkey,secret,origin,name) ' +
            'VALUES (DEFAULT,$1,$2,$3,$4,$5) RETURNING id;',
            [key, idKey, secret, origin, name], (error, result) ->
              if error
                callback error
                return
              id = result.rows[0].id
              app = new AppList.App(
                  id: id, key: key, idKey: idKey, secret: secret,
                  origin: origin, name: name)
              callback null, app
              return
    return

  # Retrieves an app.
  #
  # @param {String} key the API key of the app to be retrieved
  # @param {function(Error, AppList.App)} callback called with the app that has
  #   the given key; null will be provided if no such app exists
  # @return undefined
  findByKey: (key, callback) ->
    @_pool.query 'SELECT * FROM apps WHERE key=$1 LIMIT 1;', [key],
        (error, result) =>
          @_findCallback error, result, callback
          return
    return

  # Retrieves an app.
  #
  # @param {Number} id the internal ID of the app to be retrieved
  # @param {function(Error, AppList.App)} callback called with the app that has
  #   the given key; null will be provided if no such app exists
  # @return undefined
  findById: (id, callback) ->
    @_pool.query 'SELECT * FROM apps WHERE id=$1 LIMIT 1;', [id],
        (error, result) =>
          @_findCallback error, result, callback
          return
    return

  # Common callback shared by all finders.
  #
  # @param {Error} error given to the database operation callback
  # @param {Object} result given to the database operation callback
  # @param {function(Error, AppList.App)} callback called with the app returned
  #   by the database query
  # @return undefined
  _findCallback: (error, result, callback) ->
    if error
      callback error
      return
    if result.rowCount is 0
      callback null, null
      return

    appRow = result.rows[0]
    app = new AppList.App(
        id: appRow.id, key: appRow.key, idKey: appRow.idkey,
        secret: appRow.secret, origin: appRow.origin, name: appRow.name)
    callback null, app
    return

  # Retrieves all apps.
  #
  # @param {function(Error, Array<AppList.App>)} callback called with the list
  #   of all created apps
  # @return undefined
  list: (callback) ->
    @_pool.query 'SELECT * FROM apps;', (error, result) ->
      if error
        callback error
        return

      appRow = result.rows[0]
      apps = for appRow in result.rows
        new AppList.App(
          id: appRow.id, key: appRow.key, idKey: appRow.idkey,
          secret: appRow.secret, origin: appRow.origin, name: appRow.name)
      callback null, apps
      return
    return

  # Retrieves the master authorization key (MAK).
  #
  # If no MAK was written, a new one is generated and written.
  #
  # @param {function(Error, String)} callback
  # @return undefined
  getMak: (callback) ->
    @_fetchMak (error, mak) =>
      if error
        callback error
        return
      if mak
        callback null, mak
        return
      AppList._urlSafeRandom 32, (error, mak) =>
        if error
          callback error
          return
        @_setMak mak, (error) ->
          if error
            callback error
          else
            callback error, mak
          return
    return

  # Creates the tables needed for the app list.
  #
  # @param {function(Error)} callback called when the tables are created
  # @return undefined
  setup: (callback) ->
    queries = [
      'CREATE TABLE IF NOT EXISTS apps (' +
          'id serial PRIMARY KEY, ' +
          'key varchar(24) UNIQUE NOT NULL, ' +
          'idkey varchar(48) NOT NULL, ' +
          'secret varchar(48) NOT NULL, ' +
          'origin varchar(64) NOT NULL, ' +
          'name varchar(64) NOT NULL' +
      ');',
      'CREATE TABLE IF NOT EXISTS mak (' +
          'id integer PRIMARY KEY, ' +
          'key varchar(48) NOT NULL' +
      ');'
    ]
    runQuery = (query, next) =>
      @_pool.query query, next
    async.eachSeries queries, runQuery, callback
    return

  # Destroys the tables used by the app list.
  #
  # @param {function(Error)} callback called when the tables are removed
  # @return undefined
  teardown: (callback) ->
    queries = [
      'DROP TABLE IF EXISTS apps CASCADE;',
      'DROP TABLE IF EXISTS mak CASCADE;',
    ]
    runQuery = (query, next) =>
      @_pool.query query, next
    async.eachSeries queries, runQuery, callback
    return

  # Reads an existing master authorization key (MAK).
  #
  # @param {function(Error, String)} callback called when the read is
  #   completed; null is passed if no MAK was written
  # @return undefined
  _fetchMak: (callback) ->
    @_pool.query 'SELECT * FROM mak WHERE id=1;', (error, result) ->
      if error
        callback error
        return
      if result.rowCount is 0
        callback null, null
        return
      callback null, result.rows[0].key
      return
    return

  # Writes a master authorization key (MAK).
  #
  # @param {String} mak the key to be written
  # @param {function(Error)} callback called when the write is completed
  # @return undefined
  _setMak: (mak, callback) ->
    @_pool.query 'INSERT INTO mak (id,key) VALUES ($1,$2) RETURNING ID;',
        [1, mak], (error, result) ->
          if error
            callback error
          else
            callback null
          return

  # Ruby's SecureRandom::urlsafe_base64.
  #
  # @param {Number} size number of bytes of randomness
  # @param {function(Error, String)} callback called with an URL-safe
  #   base64-encoded cryptographically secure random number
  # @return undefined
  @_urlSafeRandom: (size, callback) ->
    crypto.randomBytes size, (error, secretBuffer) ->
      if error
        callback error
        return
      secret = secretBuffer.toString('base64').replace(/\+/g, '-').
                            replace(/\//g, '_').replace(/\=/g, '')
      callback null, secret
      return
    return

AppList.App = require './app.coffee'


module.exports = AppList
