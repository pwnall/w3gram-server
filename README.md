# Webogram Server

This is a [node.js](http://nodejs.org/) server for the
[W3gram push notification protocol](Protocol.md).

The server was designed to be deployed to [Heroku](https://www.heroku.com/)
using free resources, so it fits in a single dyno. The code has great test
coverage using [mocha](http://visionmedia.github.io/mocha/).


## Easy Setup

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

Get your server's MAK and store it somewhere safely.

```bash
curl -i https://w3gram-test.herokuapp.com/mak

# Response example:
# { "mak": "3LwwhZCuqPxO_0fNATuZbOxRgXjWuCLXzOzVaH5dZ4k" }
```

Create an application and note its API key and secret.

```bash
curl -i -X POST -H 'Content-Type: application/json' \
  -d '{"mak": "3LwwhZCuqPxO_0fNATuZbOxRgXjWuCLXzOzVaH5dZ4k", "app": { "name": "Testing", "origin": "*"}}' \
  https://w3gram-test.herokuapp.com/apps

# Response example:
# {
#    "key":"MYp4g89u3OafCtZP",
#    "secret":"z7zlLM44rFWQzmgXZX0d2r7rX9mdAP7Gg56V6YjFscY",
#    "origin":"*",
#    "name":"Testing"
# }
```

### Manual Interaction Example

Create a token for a device ID.

```bash
echo -n "device-id|my-tablet" | \
    openssl dgst -sha256 -hmac "z7zlLM44rFWQzmgXZX0d2r7rX9mdAP7Gg56V6YjFscY" \
    -binary | base64

# Response example:
# Xm3U6AU4qj7z5axtldHsNvhHqlsLdMRKQQbXoiFhmDU
```

Do the routing step.

```bash
curl -i -X POST -H 'Content-Type: application/json' \
    -d '{"app": "MYp4g89u3OafCtZP", "device": "my-tablet", "token": "Xm3U6AU4qj7z5axtldHsNvhHqlsLdMRKQQbXoiFhmDU"}' \
    https://w3gram-test.herokuapp.com/route

# Response example:
# {
#    "receiverId":"2.my-tablet.Wk3Lgc_dy0wu8smU7vHhL-Z2oDhkcF6V3Fj3O1ta2a4",
#    "push":"https://w3gram-test.herokuapp.com/push",
#    "listen":"wss://w3gram-test.herokuapp.com/ws/2.my-tablet.Wk3Lgc_dy0wu8smU7vHhL-Z2oDhkcF6V3Fj3O1ta2a4"
# }
```

Start a WebSocket connection:

```bash
wscat -c "wss://w3gram-test.herokuapp.com/ws/2.my-tablet.Wk3Lgc_dy0wu8smU7vHhL-Z2oDhkcF6V3Fj3O1ta2a4"
```

Send a notification:

```bash
curl -i -X POST -H 'Content-Type: application/json' \
    -d '{"receiver": "2.my-tablet.Wk3Lgc_dy0wu8smU7vHhL-Z2oDhkcF6V3Fj3O1ta2a4", "message": { "data": "Hello push world" } }' \
    https://w3gram-test.herokuapp.com/push
```


## Development Setup

Install all dependencies and create PostgreSQL database for development and
testing.

```bash
npm install
createdb w3gram_test
createdb w3gram_dev
```

Run the server in developmentm mode.

```bash
npm start
```


## License

This project is Copyright (c) 2014 Victor Costan, and distributed under the MIT
License.
