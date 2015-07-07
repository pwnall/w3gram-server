# W3gram Server

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)
[![Build Status](https://travis-ci.org/pwnall/w3gram-server.svg)](https://travis-ci.org/pwnall/w3gram-server)
[![API Documentation](http://img.shields.io/badge/API-Documentation-ff69b4.svg)](http://coffeedoc.info/github/pwnall/w3gram-server)
[![NPM Version](http://img.shields.io/npm/v/w3gram-server.svg)](https://www.npmjs.org/package/w3gram-server)

This is a [node.js](http://nodejs.org/) server for the
[W3gram push notification protocol](Protocol.md).

The server was designed to be deployed to [Heroku](https://www.heroku.com/)
using free resources, so it fits in a single dyno. The code has great test
coverage using [mocha](http://visionmedia.github.io/mocha/).


## Easy Setup

Click the ''Deploy to Heroku'' button at the top of this page to create your
own W3gram server running on Heroku. Don't worry, the project only uses free
add-ons!

Get your server's MAK and store it somewhere safely.

```bash
curl -i https://w3gram-test.herokuapp.com/mak

# Response example:
# { "mak": "G-TPkmtKOczXx203po1NblklXsK5OXUylUOGkQUxRQk" }
```

Create an application and note its API key and secret.

```bash
curl -i -X POST -H 'Content-Type: application/json' \
  -d '{"mak": "G-TPkmtKOczXx203po1NblklXsK5OXUylUOGkQUxRQk", "app": { "name": "Testing", "origin": "*"}}' \
  https://w3gram-test.herokuapp.com/apps

# Response example:
# {
#    "key":"uUJPS3zgIpQjDnxn",
#    "secret":"7cAXyVAYEhRbQ0UFCFI4qJAWOmXLZaPC1xX6niNIxCE",
#    "origin":"*",
#    "name":"Testing"
# }
```

### Manual Interaction Example

Create a token for a device ID.

```bash
echo -n "device-id|my-tablet" | \
    openssl dgst -sha256 -hmac "7cAXyVAYEhRbQ0UFCFI4qJAWOmXLZaPC1xX6niNIxCE" \
    -binary | base64

# Output example:
# EVwwWmwiIfLbTDV8OWsHVc4r/p2WUpKXIJcXCdtoFxM
```

Register the device.

```bash
curl -i -X POST -H 'Content-Type: application/json' \
    -d '{"app": "uUJPS3zgIpQjDnxn", "device": "my-tablet", "token": "EVwwWmwiIfLbTDV8OWsHVc4r_p2WUpKXIJcXCdtoFxM"}' \
    https://w3gram-test.herokuapp.com/register

# Response example:
# {
#    "push":"https://w3gram-test.herokuapp.com/push/1.my-tablet.WMF5TISqRYYkUr5GJWunmP40FvXI1yU_Qb5kXc907TY",
#    "route":"https://w3gram-test.herokuapp.com/route/1.my-tablet.HwVTM_07vSbHzrQHCBeHeLygUuvm5esJa2yzOjwmJwQ"
# }
```


Do the routing step.

```bash
curl -i -X POST -H 'Content-Type: application/json' -d '{}' \
    https://w3gram-test.herokuapp.com/route/1.my-tablet.WMF5TISqRYYkUr5GJWunmP40FvXI1yU_Qb5kXc907TY

# Response example:
# {
#   "listen":"wss://w3gram-test.herokuapp.com/ws/1.my-tablet.HwVTM_07vSbHzrQHCBeHeLygUuvm5esJa2yzOjwmJwQ"
# }
```

Start a WebSocket connection:

```bash
wscat -c "wss://w3gram-test.herokuapp.com/ws/1.my-tablet.HwVTM_07vSbHzrQHCBeHeLygUuvm5esJa2yzOjwmJwQ"
```

Send a notification:

```bash
curl -i -X POST -H 'Content-Type: application/json' \
    -d '{"receiver": "1.my-tablet.WMF5TISqRYYkUr5GJWunmP40FvXI1yU_Qb5kXc907TY", "message": { "data": "Hello push world" } }' \
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
