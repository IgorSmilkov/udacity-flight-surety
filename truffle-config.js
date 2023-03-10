module.exports = {
  networks: {
    // development: {
    //   provider: function() {
    //     return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/", 0, 50);
    //   },
    //   network_id: '*',
    //   gas: 9999999
    // },
    development: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*',
      accounts: 50,
    }
  },
  compilers: {
    solc: {
      version: "0.8.17"
    }
  }
};
