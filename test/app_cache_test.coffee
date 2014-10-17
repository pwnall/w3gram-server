async = require 'async'

AppList = W3gramServer.AppList
AppCache = W3gramServer.AppCache

describe 'AppCache', ->
  beforeEach ->
    @mockList = {}
    @cache = new AppCache @mockList

  describe '#getMak', ->
    beforeEach ->
      @mockList.getMakCallCount = 0
      @mockList.getMak = (callback) ->
        @getMakCallCount += 1
        callback null, 'mock-mack'
        return

    it 'calls AppList#getMak only once', (done) ->
      getValue = (_, callback) => @cache.getMak callback
      async.mapSeries [1..5], getValue, (error, result) =>
        expect(error).not.to.be.ok
        expect(result).to.be.an 'array'
        expect(result.length).to.equal 5
        for i in [1...5]
          expect(result[i]).to.equal 'mock-mack'
        expect(@mockList.getMakCallCount).to.equal 1
        done()

    it 'reports errors', (done) ->
      errorObject = {error: ''}
      @mockList.getMak = (callback) ->
        @getMakCallCount += 1
        callback errorObject
        return
      @cache.getMak (error, mak) =>
        expect(error).to.equal errorObject
        expect(mak).not.to.be.ok
        expect(@mockList.getMakCallCount).to.equal 1
        done()

  describe '#hasApps', ->
    beforeEach ->
      @apps = [{ key: 'app-key-1', id: 42 }, { key: 'app-key-2', id: 7 }]
      @mockList.listCallCount = 0
      @mockList.list = (callback) =>
        @mockList.listCallCount += 1
        callback null, @apps
        return

    it 'calls list as long as it returns no apps', (done) ->
      @apps = []
      getValue = (_, callback) => @cache.hasApps callback
      async.mapSeries [1..5], getValue, (error, result) =>
        expect(error).not.to.be.ok
        expect(result).to.be.an 'array'
        expect(result.length).to.equal 5
        for i in [1...5]
          expect(result[i]).to.equal false
        expect(@mockList.listCallCount).to.equal 5
        done()

    it 'calls list once if it returns apps', (done) ->
      getValue = (_, callback) => @cache.hasApps callback
      async.mapSeries [1..5], getValue, (error, result) =>
        expect(error).not.to.be.ok
        expect(result).to.be.an 'array'
        expect(result.length).to.equal 5
        for i in [1...5]
          expect(result[i]).to.equal true
        expect(@mockList.listCallCount).to.equal 1
        done()

    it 'updates key cache with returned apps', (done) ->
      @cache.hasApps (error, hasApps) =>
        expect(error).to.equal null
        expect(hasApps).to.equal true
        # The mock list doesn't have a findByKey method, so this will error out
        # if the cache makes a call to AppList#findbyKey.
        @cache.getAppByKey 'app-key-1', (error, app) =>
          expect(error).to.equal null
          expect(app).to.equal @apps[0]
          @cache.getAppByKey 'app-key-2', (error, app) =>
            expect(error).to.equal null
            expect(app).to.equal @apps[1]
            done()

    it 'updates key cache with returned apps', (done) ->
      @cache.hasApps (error, hasApps) =>
        expect(error).to.equal null
        expect(hasApps).to.equal true
        # The mock list doesn't have a findByKey method, so this will error out
        # if the cache makes a call to AppList#findbyKey.
        @cache.getAppById 42, (error, app) =>
          expect(error).to.equal null
          expect(app).to.equal @apps[0]
          @cache.getAppById 7, (error, app) =>
            expect(error).to.equal null
            expect(app).to.equal @apps[1]
            done()

    it 'reports errors', (done) ->
      errorObject = {error: ''}
      @mockList.list = (callback) ->
        @listCallCount += 1
        callback errorObject
        return
      @cache.hasApps (error, hasApps) =>
        expect(error).to.equal errorObject
        expect(hasApps).not.to.be.ok
        expect(@mockList.listCallCount).to.equal 1
        done()

  describe '#getAppByKey', ->
    beforeEach ->
      @app1 = { key: 'app-key-1', id: 42 }
      @app2 = { key: 'app-key-2', id: 5 }
      @errorObject = {error: ''}
      @mockList.findByKeyCallCount = 0
      @mockList.findByKey = (key, callback) =>
        @mockList.findByKeyCallCount += 1
        if key is 'app-key-1'
          callback null, @app1
        else if key is 'app-key-2'
          callback null, @app2
        else if key is 'error-key'
          callback @errorObject
        else
          callback null, null
        return

    it 'calls AppList#findByKey as long as it returns no apps', (done) ->
      @apps = []
      getValue = (_, callback) =>
        @cache.getAppByKey 'missing-app-key', callback
      async.mapSeries [1..5], getValue, (error, result) =>
        expect(error).not.to.be.ok
        expect(result).to.be.an 'array'
        expect(result.length).to.equal 5
        for i in [1...5]
          expect(result[i]).to.equal null
        expect(@mockList.findByKeyCallCount).to.equal 5
        done()

    it 'calls AppList#findByKey once if it returns apps', (done) ->
      getValue = (_, callback) => @cache.getAppByKey 'app-key-1', callback
      async.mapSeries [1..5], getValue, (error, result) =>
        expect(error).not.to.be.ok
        expect(result).to.be.an 'array'
        expect(result.length).to.equal 5
        for i in [1...5]
          expect(result[i]).to.equal @app1
        expect(@mockList.findByKeyCallCount).to.equal 1
        done()

    it 'reports errors', (done) ->
      @cache.getAppByKey 'error-key', (error, hasApps) =>
        expect(error).to.equal @errorObject
        expect(hasApps).not.to.be.ok
        expect(@mockList.findByKeyCallCount).to.equal 1
        done()

    it 'updates the hasApps cache if it returns an app', (done) ->
      @cache.getAppByKey 'app-key-1', (error, app) =>
        expect(error).to.equal null
        expect(app).to.equal @app1
        expect(@mockList.findByKeyCallCount).to.equal 1
        @cache.hasApps (error, hasApps) =>
          expect(error).to.equal null
          expect(hasApps).to.equal true
          expect(@mockList.findByKeyCallCount).to.equal 1
          done()

    it 'updates the app ID cache if it returns an app', (done) ->
      @cache.getAppByKey 'app-key-1', (error, app) =>
        expect(error).to.equal null
        expect(app).to.equal @app1
        expect(@mockList.findByKeyCallCount).to.equal 1
        @cache.getAppById 42, (error, cachedApp) =>
          expect(error).to.equal null
          expect(cachedApp).to.equal app
          expect(@mockList.findByKeyCallCount).to.equal 1
          done()

    it 'does not update the hasApps cache if it returns no apps', (done) ->
      @cache.getAppByKey 'missing-app-key', (error, app) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(@mockList.findByKeyCallCount).to.equal 1

        @mockList.listCallCount = 0
        @mockList.list = (callback) ->
          @listCallCount += 1
          callback null, []
          return
        @cache.hasApps (error, hasApps) =>
          expect(error).to.equal null
          expect(hasApps).to.equal false
          expect(@mockList.findByKeyCallCount).to.equal 1
          expect(@mockList.listCallCount).to.equal 1
          done()

  describe '#getAppById', ->
    beforeEach ->
      @app1 = { key: 'app-key-1', id: 42 }
      @app2 = { key: 'app-key-2', id: 5 }
      @errorObject = {error: ''}
      @mockList.findByIdCallCount = 0
      @mockList.findById = (id, callback) =>
        @mockList.findByIdCallCount += 1
        if id is 42
          callback null, @app1
        else if id is 5
          callback null, @app2
        else if id is 666
          callback @errorObject
        else
          callback null, null
        return

    it 'calls AppList#findById as long as it returns no apps', (done) ->
      @apps = []
      getValue = (_, callback) => @cache.getAppById 999, callback
      async.mapSeries [1..5], getValue, (error, result) =>
        expect(error).not.to.be.ok
        expect(result).to.be.an 'array'
        expect(result.length).to.equal 5
        for i in [1...5]
          expect(result[i]).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 5
        done()

    it 'calls AppList#findById once if it returns apps', (done) ->
      getValue = (_, callback) => @cache.getAppById 42, callback
      async.mapSeries [1..5], getValue, (error, result) =>
        expect(error).not.to.be.ok
        expect(result).to.be.an 'array'
        expect(result.length).to.equal 5
        for i in [1...5]
          expect(result[i]).to.equal @app1
        expect(@mockList.findByIdCallCount).to.equal 1
        done()

    it 'reports errors', (done) ->
      @cache.getAppById 666, (error, hasApps) =>
        expect(error).to.equal @errorObject
        expect(hasApps).not.to.be.ok
        expect(@mockList.findByIdCallCount).to.equal 1
        done()

    it 'updates the hasApps cache if it returns an app', (done) ->
      @cache.getAppById 42, (error, app) =>
        expect(error).to.equal null
        expect(app).to.equal @app1
        expect(@mockList.findByIdCallCount).to.equal 1
        @cache.hasApps (error, hasApps) =>
          expect(error).to.equal null
          expect(hasApps).to.equal true
          expect(@mockList.findByIdCallCount).to.equal 1
          done()

    it 'updates the app key cache if it returns an app', (done) ->
      @cache.getAppById 42, (error, app) =>
        expect(error).to.equal null
        expect(app).to.equal @app1
        expect(@mockList.findByIdCallCount).to.equal 1
        @cache.getAppByKey 'app-key-1', (error, cachedApp) =>
          expect(error).to.equal null
          expect(cachedApp).to.equal app
          expect(@mockList.findByIdCallCount).to.equal 1
          done()

    it 'does not update the hasApps cache if it returns no apps', (done) ->
      @cache.getAppById 999, (error, app) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 1

        @mockList.listCallCount = 0
        @mockList.list = (callback) ->
          @listCallCount += 1
          callback null, []
          return
        @cache.hasApps (error, hasApps) =>
          expect(error).to.equal null
          expect(hasApps).to.equal false
          expect(@mockList.findByIdCallCount).to.equal 1
          expect(@mockList.listCallCount).to.equal 1
          done()

  describe '#decodeReceiverId', ->
    beforeEach ->
      @app1 = new AppList.App key: 'app-key-1', id: 42, idKey: 'id-key-1'
      @app2 = new AppList.App key: 'app-key-2', id: 5, idKey: 'id-key-2'
      @errorObject = {error: ''}
      @mockList.findByIdCallCount = 0
      @mockList.findById = (id, callback) =>
        @mockList.findByIdCallCount += 1
        if id is 42
          callback null, @app1
        else if id is 5
          callback null, @app2
        else if id is 666
          callback @errorObject
        else
          callback null, null
        return

    it 'returns null for an empty id', (done) ->
      @cache.decodeReceiverId '', (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(key).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 0
        done()

    it 'returns null for a mis-formatted id', (done) ->
      @cache.decodeReceiverId 'misformatted-id', (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(key).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 0
        done()

    it 'returns null for an incorrect HMAC', (done) ->
      @cache.decodeReceiverId '42.tablet-device-id.aaa', (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(key).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 1
        done()

    it 'returns null for an incorrect app id', (done) ->
      @cache.decodeReceiverId '999.tablet-device-id.aaa', (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(key).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 1
        done()

    it 'returns null for a poorly formatted device ID', (done) ->
      @cache.decodeReceiverId '42.tablet device id.aaa', (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(key).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 1
        done()


    it 'returns the correct app and key for a good HMAC', (done) ->
      hmac = @app1.receiverIdHmac 'tablet-device-id'
      receiverId = "42.tablet-device-id.#{hmac}"
      @cache.decodeReceiverId receiverId, (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal @app1
        expect(key).to.equal '42_tablet-device-id'
        expect(@mockList.findByIdCallCount).to.equal 1
        done()

    it 'uses the app cache', (done) ->
      @cache.decodeReceiverId '42.tablet-device-id.aaa', (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(key).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 1
        hmac = @app1.receiverIdHmac 'tablet-device-id'
        receiverId = "42.tablet-device-id.#{hmac}"
        @cache.decodeReceiverId receiverId, (error, app, key) =>
          expect(error).to.equal null
          expect(app).to.equal @app1
          expect(key).to.equal '42_tablet-device-id'
          expect(@mockList.findByIdCallCount).to.equal 1
          done()

    it 'reports errors', (done) ->
      @cache.decodeReceiverId '666.tablet-device-id.aaa', (error, app, key) =>
        expect(error).to.equal @errorObject
        expect(@mockList.findByIdCallCount).to.equal 1
        done()

  describe '#decodeListenerId', ->
    beforeEach ->
      @app1 = new AppList.App key: 'app-key-1', id: 42, idKey: 'id-key-1'
      @app2 = new AppList.App key: 'app-key-2', id: 5, idKey: 'id-key-2'
      @errorObject = {error: ''}
      @mockList.findByIdCallCount = 0
      @mockList.findById = (id, callback) =>
        @mockList.findByIdCallCount += 1
        if id is 42
          callback null, @app1
        else if id is 5
          callback null, @app2
        else if id is 666
          callback @errorObject
        else
          callback null, null
        return

    it 'returns null for an empty id', (done) ->
      @cache.decodeListenerId '', (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(key).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 0
        done()

    it 'returns null for a mis-formatted id', (done) ->
      @cache.decodeListenerId 'misformatted-id', (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(key).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 0
        done()

    it 'returns null for an incorrect HMAC', (done) ->
      @cache.decodeListenerId '42.tablet-device-id.aaa', (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(key).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 1
        done()

    it 'returns null for an incorrect app id', (done) ->
      @cache.decodeListenerId '999.tablet-device-id.aaa', (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(key).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 1
        done()

    it 'returns null for a poorly formatted device ID', (done) ->
      @cache.decodeListenerId '42.tablet device id.aaa', (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(key).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 1
        done()


    it 'returns the correct app and key for a good HMAC', (done) ->
      hmac = @app1.listenerIdHmac 'tablet-device-id'
      listenerId = "42.tablet-device-id.#{hmac}"
      @cache.decodeListenerId listenerId, (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal @app1
        expect(key).to.equal '42_tablet-device-id'
        expect(@mockList.findByIdCallCount).to.equal 1
        done()

    it 'uses the app cache', (done) ->
      @cache.decodeListenerId '42.tablet-device-id.aaa', (error, app, key) =>
        expect(error).to.equal null
        expect(app).to.equal null
        expect(key).to.equal null
        expect(@mockList.findByIdCallCount).to.equal 1
        hmac = @app1.listenerIdHmac 'tablet-device-id'
        listenerId = "42.tablet-device-id.#{hmac}"
        @cache.decodeListenerId listenerId, (error, app, key) =>
          expect(error).to.equal null
          expect(app).to.equal @app1
          expect(key).to.equal '42_tablet-device-id'
          expect(@mockList.findByIdCallCount).to.equal 1
          done()

    it 'reports errors', (done) ->
      @cache.decodeListenerId '666.tablet-device-id.aaa', (error, app, key) =>
        expect(error).to.equal @errorObject
        expect(@mockList.findByIdCallCount).to.equal 1
        done()

