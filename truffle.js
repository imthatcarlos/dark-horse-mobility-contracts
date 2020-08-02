const HDWalletProvider = require('@truffle/hdwallet-provider');

require('dotenv').config();

const {
  PRIVATE_KEY_BRAVE,
  INFURA_API_KEY
} = process.env;

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
    },
    ropsten: {
      provider: function() {
        return new HDWalletProvider(PRIVATE_KEY_BRAVE, 'https://ropsten.infura.io/v3/' + INFURA_API_KEY)
      },
      network_id: '3',
      gas: 4500000
    }
  }
};
