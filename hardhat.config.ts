import "@matterlabs/hardhat-zksync-toolbox";

const config = {
  zksolc: {
    version: "1.3.8",
    compilerSource: "binary",
    settings: {},
  },
  defaultNetwork: "zkSyncEra",
  networks: {
    zkSyncEra: {
      url: "https://zksync2-testnet.zksync.dev",
      ethNetwork: "goerli",
      zksync: true,
    },
    zkSyncLocal: {
      url: "http://localhost:3050",
      ethNetwork: "http://localhost:8545",
      zksync: true,
    },
  },
  solidity: {
    compilers: [
      {version: "0.6.12"},
      {version: "0.8.8"}
    ]
  },
};

export default config;
