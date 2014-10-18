# The W3gram Protocol

This document outlines the protocols used to communicate between the W3gram
push notification server (PNS) and the app server, as well as between the
notification server and a client (running in a browser) that receives
notifications.


## Status

The W3gram protocol is currently unstable. It is guaranteed to undergo
revisions at least until it can be used to implement the
[W3C Push API](http://w3c.github.io/push-api/).


## Generic Considerations

The following considerations apply to the all the following sections.

### JSON

[JSON](http://json.org/) is used extensively throughout the protocol.

All the HTTP responses from the W3gram server use JSON in their bodies, and
have the `Content-Type` header set to `application/json`.

All the POST request bodies must use JSON, and have the `Content-Type` header
set to `application/json`.

The examples below show (somewhat) pretty-printed JSON for illustration
purposes. Implementations should minimize the use of whitespace, to preserve
bandwidth, CPU cycles, and battery power.

### CORS

The protocol is REST-ful enough that enabling
[CORS](http://www.w3.org/TR/cors/) on the push notification server will not
introduce any security issues. Therefore, notification servers should be
CORS-enabled.

The protocol only uses GET and POST requests, to facilitate the implementation
of clients in legacy browsers. To support CORS, servers should respond to
OPTIONS requests for the paths that accept POST requests. OPTIONS responses
should include at least `POST` in the `Accress-Control-Allow-Methods` header,
and should set a very large value for the `Access-Control-Max-Age` header.

Furthermore, the protocol uses the `Origin` header sent by CORS-compliant
browsers to curb unauthorized usage of notification server resources.

Preflight request example:

```javascript
OPTIONS /route
Access-Control-Request-Method: POST
Origin: https://example.app.com
```

Preflight response example:

```javascript
204 No Content
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: POST
Access-Control-Max-Age: 31536000
```

### HTTP Errors and Retrying

Protocol clients may retry HTTP requests when receiving responses with status
codes betwene 500-599. Retries should use exponential backoff.

Clients should not retry requests that receive HTTP status codes between
400-499.


## Provisioning API

The provisioning API is used to set up credentials for an application that will
use a push notification server.

The API is used very rarely (once per application), so there are few incentives
to keep it stable. The version documented here covers the server implementation
in this repository, and should not be considered normative.

### Get the MAK

After a notification server is deployed on Heroku, its owner must first
retrieve the server's master authorization key (MAK). The MAK is required to
register applications, which prevents a leeching application developer from
using someone else's server.

A server will not return its MAK after its first application has been
provisioned.

Request example:

```javascript
GET /mak
Origin: https://example.app.com
```

Response example:

```javascript
200 OK
Content-Type: application/json
Access-Control-Allow-Origin: *

{ "mak": "the-mak-value-for-the-server" }
```

Error example:

```javascript
403 Not Authorized
Access-Control-Allow-Origin: *
```


### Provision an Application

The application's developers must provision it on the notification server
before the application can send notifications.

Request example:

```javascript
POST /apps
Content-Type: application/json

{
  "mak": "the-mak-value-for-the-server",
  "app": {
    "name": "News and Updates",
    "origin": "news-and-updates.com",
  }
}
```

Response example:

```javascript
201 Created
Access-Control-Allow-Origin: *
Content-Type: application/json

{
  "app": {
    "key": "news-api-key",
    "secret": "secret-token",
    "name": "News and Updates",
    "origin": "news-and-updates.com"
  }
}
```

The application's key is used to identify the application on the notification
server. It is public information.

The application's developers must store the application's secret securely on
the server. The client side of an application (the part that runs in a browser
or another untrusted device) should never receive the secret.


## Receiver API

The receiver API is used by notification receivers, which usually run on
untrusted devices, such as the application users' Web browsers.

### Register a Device

The application server must assign a unique device ID to each user device that
requires notifications. In order to manage load, the push notification server
may (and should) terminate old connections associated with the same API key and
device ID as an incoming connection.

To prevent against unauthorized use, the application server must use its secret
to sign the device ID. This limits a leeching application developer to using
device IDs (and tokens) that it can obtain from the legitimate application
server.

The token is computed using a
[SHA-256](http://csrc.nist.gov/groups/STM/cavp/documents/shs/sha256-384-512.pdf)
[HMAC](http://tools.ietf.org/html/rfc2104) of the string
`"device-id|" || device-id`, and then encoding the result using the
[URL-safe base64 encoding in RFC 4648](http://tools.ietf.org/html/rfc4648#section-5)


The notification server responds with a receiver ID and push URL that can be
used by the application server to send notifications to the receiver
application.

If possible, different devices for the same application should share the same
push URL, so the application server can reuse an HTTP connection to push
notifications to multiple devices.

If the token is missing or invalid, the notification server should use the 400
HTTP status code. The 403 code might be more appropriate, but it triggers a
CORS request bug in some versions of Safari, and may cause problems in other
browsers as well.

The notification server should use the
[429 HTTP status code](http://tools.ietf.org/html/rfc6585#section-4) if the
application has exceeded the number of devices that it is allowed to
(simultaneouly) register to the server.

Request example:

```javascript
POST /register
Content-Type: application/json

{
  "app": "news-api-key",
  "device": "tablet-device-id",
  "token": "DtzV3N04Ao7eJb-H09CAk0GxgREOlOvAEAbBc4H4HAQ"
}
```

Response example:

```javascript
200 OK
Access-Control-Allow-Origin: *
Content-Type: application/json

{
  "receiver": "backend.receiver-identifier",
  "push": "https://push.w3gram-example.com/push/"
}
```

Error example:

```javascript
400 Bad Request
Access-Control-Allow-Origin: *
Content-Type: application/json

{
  "error": "Invalid token"
}
```

### Route a Receiver

The protocol starts with a routing step, which affords the push notification
server implementation an easy way to load-balance among clients.

The result of the routing protocol is a WebSocket URL that the receiver
application must connect to in order to receive the notifications. The
WebSocket protocol (defined below) has no provision for specifying receiver
information, so the WebSocket URL returned by the routing step should encode
the receiver's information.

For security reasons, it should not be possible to compute all the receiver
information encoded in the WebSocket URL based on the information used during
registration (API key, device ID, receiver ID). This allows e.g., a chat
application to pass receiver IDs among its users, without having to worry that
a user will be able to use another user's receiver ID to listen in on the
other user's notifications.

If the token is missing or invalid, the notification server should use the 400
HTTP status code. The 403 code might be more appropriate, but it triggers a
CORS request bug in some versions of Safari, and may cause problems in other
browsers as well.

The notification server should use the 410 HTTP status code if the receiver ID
does not match the current receiver ID for the device ID. This can happen if
two clients run the registration and listening process simultaneously.

The notification server should use the
[429 HTTP status code](http://tools.ietf.org/html/rfc6585#section-4) if the
application has exceeded the number of devices that it is allowed to
(simultaneouly) connect to the server.

Request example:

```javascript
POST /route
Content-Type: application/json

{
  "app": "news-api-key",
  "device": "tablet-device-id",
  "token": "DtzV3N04Ao7eJb-H09CAk0GxgREOlOvAEAbBc4H4HAQ"
  "receiver": "backend.receiver-identifier",
}
```

Response example:

```javascript
200 OK
Access-Control-Allow-Origin: *
Content-Type: application/json

{
  "listen": "wss://ws.w3gram-example.com/ws/backend.receiver-listener-id",
}
```

Error example:

```javascript
410 Gone
Access-Control-Allow-Origin: *
Content-Type: application/json

{
  "error": "Invalid or outdated receiver ID"
}
```

### Receive Notifications

The receiver application must maintain a persistent connection to the WebSocket
URL obtained in the routing step in order to receive notifications. This
section describes the WebSocket protocol.

The receiver software should connect to the WebSocket URL received during the
routing step.

The server and client exchange JSON-encoded WebSocket text frames. The `type`
key in the JSON object indicates the request type.

#### WebSocket Open

The
[WebSocket open event](http://dev.w3.org/html5/websockets/#handler-websocket-onopen)
does not work properly cross-browser. When a receiver connects via a WebSocket,
the W3gram server immediately sends a `hi` message. Clients can use this
instead of having to rely on the `open` event.

Open example:

```json
{
  "type": "hi",
  "data": { "version": 0 }
}
```

#### WebSocket Keep-Alive

The client should periodically send `ping` requests to keep the connection
alive. The server responds with a `pong` that mirrors the `data` property of
the ping. The client can use the `data` to store information for RTT
estimation, duplicate detection, etc.

Note that the protocol does not rely on the Ping and Pong frames defined in
[RFC 6455 Section 5.5.2](https://tools.ietf.org/html/rfc6455#section-5.5.2)
and
[RFC 6455 Section 5.5.3](https://tools.ietf.org/html/rfc6455#section-5.5.3).

Request example:

```json
{
  "type": "ping",
  "data": { "ts": 1413422099401 }
}
```

Response example:

```json
{
  "type": "pong",
  "data": { "ts": 1413422099401 }
}
```

#### Notifications

The server sends a `note` request to push a notification to the receiver. The
`data` property contains the notification, which is a JSON object.

Notification example:

```json
{
  "type": "note":
  "data": { "text": "Hello push world" }
}
```

#### WebSocket Close Codes

The WebSocket server can close the connection during the HTTP Upgrade request
with the following codes.

* 400 - the listener ID is missing or invalid
* 403 - the Origin header does not contain an authorized origin
* 429 - the application developer has exceeded its quota of (simultaneous)
  device connections

The WebSocket server can close the socket using one of the
following codes.

* 4410 - the push server has received another connection using the same device
  ID
* 4400 - the receiver sent a malformed (non-JSON) request, or the request was
  too large
* 4404 - the receiver sent a request that was not understood by the server
* 1001 - the WebSocket server is shutting down; the receiver should try
  re-connecting to the same WebSocket URL, using exponential backoff

Upon receiving a 4410, 4400, or 4404 code, the receiver should not attempt to
re-connect to the server.


## Server API

After completing the routing step, a notification receiver sends its push URL
and receiver ID to the application server, which uses them to send
notifications.

To save resources, the application server can (and should) attempt to reuse an
HTTP connection for pushing notifications to different receivers with the same
push URL.

### Send a Notification

If the receiver ID is not known, the notification server should use the 410
HTTP status code.

The notification server should use the
[429 HTTP status code](http://tools.ietf.org/html/rfc6585#section-4) if the
application has exceeded the number of devices that it is allowed to
(simultaneouly) connect to the server.

Request example:

```javascript
POST /push-url-obtained-from-routing
Content-Type: application/json

{
  "receiver": "backend.receiver-identifier",
  "message": { "text": "Hello push world!" }
}
```

Response example:

```javascript
204 No Content
Access-Control-Allow-Origin: *
```

Unknown receiver error example:

```javascript
410 Gone
Access-Control-Allow-Origin: *
Content-Type: application/json

{
  "error": "Unknown receiver"
}
```

Generic error example:

```javascript
400 Bad Request
Access-Control-Allow-Origin: *
Content-Type: application/json

{
  "error": "Message too long"
}
```
