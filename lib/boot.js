if (process.env.NODETIME_ACCOUNT_KEY) {
  require('nodetime').profile({
    accountKey: process.env.NODETIME_ACCOUNT_KEY
  });
}

require('./index.js').bootServer()
