App = W3gramServer.AppList.App

describe 'App', ->
  beforeEach ->
    @app = new App(
      id: 42, key: 'news-app-key', idKey: 'news-app-id-key',
      secret: 'secret-token', name: 'Example App',
      origin: 'https://example.app.com')

  describe '.isValidDeviceId', ->
    it 'rejects long device IDs', ->
      deviceId = (new Array(66)).join 'a'
      expect(deviceId.length).to.equal 65
      expect(App.isValidDeviceId(deviceId)).to.equal false

    it 'rejects empty device IDs', ->
      expect(App.isValidDeviceId('')).to.equal false

    it 'rejects device IDs with invalid characters', ->
      expect(App.isValidDeviceId('invalid deviceid')).to.equal false
      expect(App.isValidDeviceId('invalid@deviceid')).to.equal false
      expect(App.isValidDeviceId('invalid.deviceid')).to.equal false
      expect(App.isValidDeviceId('invalid+deviceid')).to.equal false

    it 'accepts 64-byte IDs', ->
      deviceId = (new Array(65)).join 'a'
      expect(deviceId.length).to.equal 64
      expect(App.isValidDeviceId(deviceId)).to.equal true

    it 'accepts IDs with digits, letters, and - _', ->
      expect(App.isValidDeviceId('0129abczABCZ-_')).to.equal true

  describe '.isValidAppKey', ->
    it 'rejects long app keys', ->
      appKey = (new Array(26)).join 'a'
      expect(appKey.length).to.equal 25
      expect(App.isValidAppKey(appKey)).to.equal false

    it 'rejects empty app keys', ->
      expect(App.isValidAppKey('')).to.equal false

    it 'rejects app keys with invalid characters', ->
      expect(App.isValidAppKey('invalid appkey')).to.equal false
      expect(App.isValidAppKey('invalid@appkey')).to.equal false
      expect(App.isValidAppKey('invalid.appkey')).to.equal false
      expect(App.isValidAppKey('invalid+appkey')).to.equal false

    it 'accepts 24-byte keys', ->
      appKey = (new Array(25)).join 'a'
      expect(appKey.length).to.equal 24
      expect(App.isValidAppKey(appKey)).to.equal true

    it 'accepts keys with digits, letters, and - _', ->
      expect(App.isValidAppKey('0129abczABCZ-_')).to.equal true

  describe '.isValidAppSecret', ->
    it 'rejects long app secrets', ->
      appSecret = (new Array(50)).join 'a'
      expect(appSecret.length).to.equal 49
      expect(App.isValidAppSecret(appSecret)).to.equal false

    it 'rejects empty app secrets', ->
      expect(App.isValidAppSecret('')).to.equal false

    it 'rejects app secrets with invalid characters', ->
      expect(App.isValidAppSecret('invalid appsecret')).to.equal false
      expect(App.isValidAppSecret('invalid@appsecret')).to.equal false
      expect(App.isValidAppSecret('invalid.appsecret')).to.equal false
      expect(App.isValidAppSecret('invalid+appsecret')).to.equal false

    it 'accepts 48-byte secrets', ->
      appSecret = (new Array(49)).join 'a'
      expect(appSecret.length).to.equal 48
      expect(App.isValidAppSecret(appSecret)).to.equal true

    it 'accepts secrets with digits, letters, and - _', ->
      expect(App.isValidAppSecret('0129abczABCZ-_')).to.equal true

  describe '._hmac', ->
    it 'works on the RFC 4231 test case 2', ->
      expect(App._hmac('Jefe', 'what do ya want for nothing?')).to.equal(
          'W9zBRr9gdU5qBCQmCJV1x1oAPwidJzmDnexYuWTsOEM')

  describe '#acceptsOrigin', ->
    describe 'when set', ->
      it 'returns true for null origin', ->
        expect(@app.acceptsOrigin(null)).to.equal true

      it 'returns true when the origin matches', ->
        expect(@app.acceptsOrigin('https://example.app.com')).to.equal true

      it 'returns false for a port mismatch', ->
        expect(@app.acceptsOrigin('https://example.app.com:8443')).to.equal false

      it 'returns false for a protocol mismatch', ->
        expect(@app.acceptsOrigin('http://example.app.com')).to.equal false

      it 'returns false for a host mismatch', ->
        expect(@app.acceptsOrigin('http://another.app.com')).to.equal false

    describe 'when set to *', ->
      beforeEach ->
        @app.origin = '*'

      it 'returns true for null origin', ->
        expect(@app.acceptsOrigin(null)).to.equal true

      it 'returns true for an https origin', ->
        expect(@app.acceptsOrigin('https://some.app.com')).to.equal true

      it 'returns true for an https+port origin', ->
        expect(@app.acceptsOrigin('https://some.app.com:8443')).to.equal true

      it 'returns true for an http origin', ->
        expect(@app.acceptsOrigin('http://some.app.com')).to.equal true

      it 'returns true for a file origin', ->
        expect(@app.acceptsOrigin('file:null')).to.equal true

  describe '#token', ->
    it 'returns null for invalid device IDs', ->
      expect(@app.token('invalid device')).to.equal null

    it 'works on the documentation example', ->
      expect(@app.token('tablet-device-id')).to.equal(
          'DtzV3N04Ao7eJb-H09CAk0GxgREOlOvAEAbBc4H4HAQ')

  describe '#receiverIdHmac', ->
    it 'returns null for invalid device IDs', ->
      expect(@app.receiverIdHmac('invalid device')).to.equal null

    it 'works on the documentation example', ->
      hmac = App._hmac 'news-app-id-key',
                       'signed-id|receiver|42|tablet-device-id'
      expect(@app.receiverIdHmac('tablet-device-id')).to.equal hmac

  describe '#receiverId', ->
    it 'returns null for invalid device IDs', ->
      expect(@app.receiverId('invalid device')).to.equal null

    it 'works on the documentation example', ->
      hmac = App._hmac 'news-app-id-key',
                       'signed-id|receiver|42|tablet-device-id'
      expect(@app.receiverId('tablet-device-id')).to.equal(
          "42.tablet-device-id.#{hmac}")

  describe '#listenerIdHmac', ->
    it 'returns null for invalid device IDs', ->
      expect(@app.listenerIdHmac('invalid device')).to.equal null

    it 'works on the documentation example', ->
      hmac = App._hmac 'news-app-id-key',
                       'signed-id|listener|42|tablet-device-id'
      expect(@app.listenerIdHmac('tablet-device-id')).to.equal hmac

  describe '#listenerId', ->
    it 'returns null for invalid device IDs', ->
      expect(@app.listenerId('invalid device')).to.equal null

    it 'works on the documentation example', ->
      hmac = App._hmac 'news-app-id-key',
                       'signed-id|listener|42|tablet-device-id'
      expect(@app.listenerId('tablet-device-id')).to.equal(
          "42.tablet-device-id.#{hmac}")

  describe '#hashKey', ->
    it 'returns null for invalid device IDs', ->
      expect(@app.hashKey('invalid device')).to.equal null

    it 'works on the documentation example', ->
      expect(@app.hashKey('tablet-device-id')).to.equal '42_tablet-device-id'

  describe '#json', ->
    it 'includes the public fields', ->
      json = @app.json()
      expect(json).to.be.an 'object'
      expect(json.key).to.equal @app.key
      expect(json.secret).to.equal @app.secret
      expect(json.origin).to.equal @app.origin
      expect(json.name).to.equal @app.name

    it 'does not include the ID key', ->
      json = @app.json()
      expect(json).to.be.an 'object'
      expect(json).not.to.have.property 'idKey'
      for property of json
        expect(json[property]).not.to.equal @app.idKey
