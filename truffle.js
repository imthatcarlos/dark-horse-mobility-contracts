// const HDWalletProvider = require('@truffle/hdwallet-provider');

require('dotenv').config();

module.exports = {
  compilers: {
     solc: {
       version: '0.6.0'
     }
  },
  mocha: {
    useColors: true
  },
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*'
    }
  }
};
