import { Deployer } from "@matterlabs/hardhat-zksync-toolbox";
import * as dotenv from "dotenv";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Wallet } from "zksync-web3";

dotenv.config();

const deployDexV2 = async (hre: HardhatRuntimeEnvironment) => {

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

  // // WETH deployment
  // const WETH_artifact = await deployer.loadArtifact("WETH");
  // console.log(`${WETH_artifact.contractName} contract deployment started...`);
  // const WETH = await deployer.deploy(WETH_artifact);
  // console.log(`${WETH_artifact.contractName} contract deployment finished`);
  // console.log(`Contract address: ${WETH.address}`);

  // // WETH verification
  // const WethName = "contracts/dex-v2/token/WETH.sol:WETH";
  // const WethId = await hre.run("verify:verify", {
  //   address: WETH.address,
  //   contract: WethName,
  //   bytecode: WETH_artifact.bytecode,
  // });

  // // Factory deployment
  // const Factory_artifact = await deployer.loadArtifact("FactoryDynamic");
  // const feeSetter = process.env.PUBLIC_KEY;
  // const Factory = await deployer.deploy(Factory_artifact, [feeSetter]);
  // console.log(`${Factory_artifact.contractName} contract deployment finished`);
  // console.log(`Contract address: ${Factory.address}`);

  // // Factory verification
  // const FactoryName = "contracts/dex-v2/dynamic/FactoryDynamic.sol:FactoryDynamic";
  // const FactoryId = await hre.run("verify:verify", {
  //   address: Factory.address,
  //   contract: FactoryName,
  //   constructorArguments: [
  //     feeSetter
  //   ],
  //   bytecode: Factory_artifact.bytecode,
  // });

  const Factory = {address: "0xe676f869Bc03cF76Aed4C88120dcA4b43063c360"};
  const WETH = {address: "0x92FF5E67e4F164821f8F7bD2B0C48B9bBAdB95a4"};

  // Router Deployment
  const Router_artifact = await deployer.loadArtifact("RouterDynamic");
  const Router = await deployer.deploy(Router_artifact, [Factory.address, WETH.address]);
  console.log(`${Router_artifact.contractName} contract deployment finished`);
  console.log(`Contract address: ${Router.address}`);
  
  // Router Verification
  const RouterName = "contracts/dex-v2/dynamic/RouterDynamic.sol:RouterDynamic";
  const RouterId = await hre.run("verify:verify", {
    address: Router.address,
    contract: RouterName,
    constructorArguments: [
      Factory.address,
      WETH.address
    ],
    bytecode: Router_artifact.bytecode,
  });

};

export default deployDexV2;