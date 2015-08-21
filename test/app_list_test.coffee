async = require 'async'

AppList = W3gramServer.AppList

describe 'AppList', ->
  before (done) ->
    @appList = w3gram_test_config.appList()
    @appList.teardown (error) =>
      if error
        console.error error
        process.exit 1
      done()

  beforeEach (done) ->
    @appList.setup (error) ->
      if error
        console.error error
        process.exit 1
      done()

  afterEach (done) ->
    @appList.teardown (error) ->
      if error
        console.error error
        process.exit 1
      done()

  describe '._urlSafeRandom', ->
    it 'returns a string', (done) ->
      AppList._urlSafeRandom 16, (error, value) ->
        expect(error).to.equal null
        expect(value).to.be.a 'string'
        expect(value.length).to.equal 22  # ceil(16 * 4 / 3)
        done()

    it 'returns different strings', (done) ->
      getValue = (_, callback) ->
        AppList._urlSafeRandom 16, callback
      async.map [1..10], getValue, (error, result) ->
        expect(result).to.be.an 'array'
        expect(result.length).to.equal 10
        for i in [1...10]
          expect(result[i]).not.to.equal result[i + 1]
        done()

    it 'respects the length argument', (done) ->
      getValue = (size, callback) ->
        AppList._urlSafeRandom size, callback
      async.map [12, 16, 32], getValue, (error, result) ->
        expect(result).to.be.an 'array'
        expect(result.length).to.equal 3
        expect(result[0].length).to.equal 16
        expect(result[1].length).to.equal 22
        expect(result[2].length).to.equal 43
        done()

  describe '#create', ->
    it 'returns an App', (done) ->
      options = name: 'webogram-prod', origin: 'https://test.app.com'
      @appList.create options, (error, app) ->
        expect(error).to.equal null
        expect(app).to.be.an.instanceOf AppList.App
        expect(app.name).to.equal 'webogram-prod'
        expect(app.origin).to.equal 'https://test.app.com'
        expect(app.key).to.be.a 'string'
        expect(app.key.length).to.be.at.least 16
        expect(app.idKey).to.be.a 'string'
        expect(app.idKey.length).to.be.at.least 16
        expect(app.secret).to.be.a 'string'
        expect(app.secret.length).to.be.at.least 42
        expect(app.id).to.be.a 'number'
        done()

    it 'uses a provided key and secret', (done) ->
      options =
          name: 'webogram-prod', origin: 'https://test.app.com'
          key: 'a-test-key', secret: 'a-test-secret'
      @appList.create options, (error, app) ->
        expect(error).to.equal null
        expect(app).to.be.an.instanceOf AppList.App
        expect(app.name).to.equal 'webogram-prod'
        expect(app.origin).to.equal 'https://test.app.com'
        expect(app.key).to.equal 'a-test-key'
        expect(app.idKey).to.be.a 'string'
        expect(app.idKey.length).to.be.at.least 16
        expect(app.secret).to.equal 'a-test-secret'
        expect(app.id).to.be.a 'number'
        done()

  describe '#findByKey', ->
    beforeEach (done) ->
      @appList.create name: 'get-test', (error, app) =>
        expect(error).to.equal null
        @key = app.key
        done()

    it 'returns null for an invalid id', (done) ->
      @appList.findByKey 'no-such-key', (error, app) ->
        expect(error).to.equal null
        expect(app).to.equal null
        done()

    it 'returns a previously created app', (done) ->
      @appList.findByKey @key, (error, app) =>
        expect(error).to.equal null
        expect(app).to.be.an.instanceOf AppList.App
        expect(app.name).to.equal 'get-test'
        expect(app.origin).to.equal '*'
        expect(app.key).to.equal @key
        expect(app.idKey).to.be.a 'string'
        expect(app.id).to.be.a 'number'
        done()

  describe '#findById', ->
    beforeEach (done) ->
      @appList.create name: 'get-test', (error, app) =>
        expect(error).to.equal null
        @id = app.id
        done()

    it 'returns null for an invalid id', (done) ->
      @appList.findById 0, (error, app) ->
        expect(error).to.equal null
        expect(app).to.equal null
        done()

    it 'returns a previously created app', (done) ->
      @appList.findById @id, (error, app) =>
        expect(error).to.equal null
        expect(app).to.be.an.instanceOf AppList.App
        expect(app.name).to.equal 'get-test'
        expect(app.origin).to.equal '*'
        expect(app.id).to.equal @id
        expect(app.key).to.be.a 'string'
        expect(app.idKey).to.be.a 'string'
        expect(app.id).to.be.a 'number'
        done()

  describe '#list', ->
    describe 'with no apps', ->
      it 'returns an empty array', (done) ->
        @appList.list (error, apps) =>
          expect(error).to.equal null
          expect(apps).to.be.an 'array'
          expect(apps.length).to.equal 0
          done()

    describe 'with 3 apps', ->
      beforeEach (done) ->
        appOptions = [
          {name: 'list-test1', origin: 'https://list.test1.com'},
          {name: 'list-test2', origin: 'https://list.test2.com'},
          {name: 'list-test3', origin: 'https://list.test3.com'},
        ]
        createApp = (options, next) =>
          @appList.create options, (error, app) =>
            if error
              next error
              return
            next null, app
        async.mapSeries appOptions, createApp, (error, apps) =>
          expect(error).to.not.be.ok
          @apps = apps
          done()

      it 'returns all the apps', (done) ->
        @appList.list (error, apps) =>
          expect(error).to.equal null
          expect(apps).to.be.an 'array'
          expect(apps.length).to.equal @apps.length
          for app in apps
            expect(app).to.be.an.instanceOf AppList.App
          expect(app.key for app in apps).to.deep.equal(
              app.key for app in @apps)
          expect(app.secret for app in apps).to.deep.equal(
              app.secret for app in @apps)
          expect(app.idKey for app in apps).to.deep.equal(
              app.idKey for app in @apps)
          expect(app.name for app in apps).to.deep.equal(
              ['list-test1', 'list-test2', 'list-test3'])
          expect(app.origin for app in apps).to.deep.equal(
              ['https://list.test1.com', 'https://list.test2.com',
               'https://list.test3.com'])
          expect(app.id for app in apps).to.deep.equal([1, 2, 3])
          done()

  describe '#_fetchMak', ->
    describe 'with an empty table', ->
      it 'returns null', (done) ->
        @appList._fetchMak (error, mak) ->
          expect(error).to.equal null
          expect(mak).to.equal null
          done()

    describe 'after #_setMak', ->
      beforeEach (done) ->
        @appList._setMak 'fetch-test-mak', (error) ->
          expect(error).not.to.be.ok
          done()

      it 'returns the previously set MAK', (done) ->
        @appList._fetchMak (error, mak) ->
          expect(error).to.equal null
          expect(mak).to.equal 'fetch-test-mak'
          done()

  describe '#getMak', ->
    it 'returns the same value', (done) ->
      getValue = (_, next) => @appList.getMak next
      async.mapSeries [1..5], getValue, (error, values) ->
        expect(error).not.to.be.ok
        expect(values.length).to.equal 5
        for i in [1...5]
          expect(values[i]).to.equal values[0]
        done()
