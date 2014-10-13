global.chai = require 'chai'
global.sinon = require 'sinon'

sinonChai = require 'sinon-chai'
global.chai.use sinonChai

global.W3gramServer = require '../lib/index.js'

global.w3gram_test_config = new W3gramServer.Config(
  pg_database: 'postgres://localhost/w3gram_test'
  pg_pool_min: 2
  pg_pool_max: 5
  port: null)

global.assert = global.chai.assert
global.expect = global.chai.expect
