// export default deploy;

import { Deployer } from "@matterlabs/hardhat-zksync-toolbox";
import * as dotenv from "dotenv";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Wallet } from "zksync-web3";

// env vars from the .env file.
dotenv.config();

const deploy = async (hre: HardhatRuntimeEnvironment) => {
  let foundationWallet ="0xaD0E8c02B464065048976C3e88236B147f70Ad7e"
  let BYNAddress = "0xf08454c5434DaD5Cd0B6ee9137bCC5c65abdF31d"
  console.log(`Running example deploy script for the Greeter contract`);
  console.log();

  // private key from env var
  const privateKey =
    hre.network.name === "zkSyncLocal"
      ? process.env.LOCAL_TESTNET_RICH_WALLET_PRIVATE_KEY
      : process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error(
      `Please set your PRIVATE_KEY in the '.env' file. Use the '.env.example' file as an example.`
    );
  }

  // artifact loading
  const wallet = new Wallet(privateKey);
  const deployer = new Deployer(hre, wallet);

  const NLP_artifact = await deployer.loadArtifact("NLPToken");

  // contract deployment
  console.log(`${NLP_artifact.contractName} contract deployment started...`);
  const NLP = await deployer.deploy(NLP_artifact,[
    "100000000000000000000000000"
  ]);
  console.log(`${NLP_artifact.contractName} contract deployment finished.`);
  console.log(`Contract address: ${NLP.address}`);

  var rewardPerBlock = 27714000000000000;
  const Masterchif_artifact = await deployer.loadArtifact("MasterChefV2");
  console.log(
    `${Masterchif_artifact.contractName} contract deployment started...`
  );
  const Masterchif = await deployer.deploy(Masterchif_artifact, [
    NLP.address,
    foundationWallet,
    rewardPerBlock.toString(),
    93882,
    94787
  ]);
  console.log(
    `${Masterchif_artifact.contractName} contract deployment finished.`
  );
  console.log(`Contract address: ${Masterchif.address}`);

    const Vester_artifact = await deployer.loadArtifact("Vester");
    console.log(`${Vester_artifact.contractName} contract deployment started...`);
    const Vesting = await deployer.deploy(Vester_artifact, [
      "Vested BYN",
      "veBYN",
      31536000,
      BYNAddress,
      NLP.address,
      foundationWallet
    ]);
 
};

export default deploy;


