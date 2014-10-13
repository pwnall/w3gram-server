# Starts up the W3gram server.
bootServer = ->
  Config = require('./config.coffee')
  config = new Config(
    port: process.env['PORT'] || '3000'
    pg_database: process.env['DATABASE_URL'] ||
                 'postgres://localhost/w3gram_dev'
    pg_pool_min: process.env['DATABASE_POOL_MIN'] || '1'
    pg_pool_max: process.env['DATABASE_POOL_MAX'] || '5'
  )
  server = config.server()
  config.appList().setup ->
    server.listen ->
      console.info "Listening for connections at #{server.listenAddress()}"


module.exports = bootServer
