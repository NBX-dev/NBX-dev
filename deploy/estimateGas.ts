import { Deployer } from "@matterlabs/hardhat-zksync-toolbox";
import * as dotenv from "dotenv";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Wallet } from "zksync-web3";

dotenv.config();

const estimateGas = async (hre: HardhatRuntimeEnvironment) => {

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

  const genericAddress = "0x2F5CdC894a519809b8b8d958493084db9D5164f2";
  // artifact loading
  const wallet = new Wallet(privateKey);
  const deployer = new Deployer(hre, wallet);

  // WETH estimates
  const WETH_artifact = await deployer.loadArtifact("WETH");
  const WETH_Fee = await deployer.estimateDeployGas(WETH_artifact, []);
  console.log(`${WETH_artifact.contractName} contract deployment fee:`, WETH_Fee.toNumber());

  // Factory estimates
  const Factory_artifact = await deployer.loadArtifact("FactoryDynamic");
  const Factory_Fee = await deployer.estimateDeployGas(Factory_artifact, []);
  console.log(`${Factory_artifact.contractName} contract deployment fee:`, Factory_Fee.toNumber());

  // Router estimates
  const Router_artifact = await deployer.loadArtifact("RouterDynamic");
  const Router_Fee = await deployer.estimateDeployGas(Router_artifact, [genericAddress, genericAddress]);
  console.log(`${Router_artifact.contractName} contract deployment fee:`, Router_Fee.toNumber());

  const Masterchef_artifact = await deployer.loadArtifact("MasterChefV2");
  const Masterchef_Fee = await deployer.estimateDeployGas(Masterchef_artifact, [genericAddress, genericAddress, "100000000000000000000", 93882, 94787]);
  console.log(`${Masterchef_artifact.contractName} contract deployment fee:`, Masterchef_Fee.toNumber());

  const Vester_artifact = await deployer.loadArtifact("Vester");
  const Vester_Fee = await deployer.estimateDeployGas(Vester_artifact, [ "Vested BYN", "veBYN", 31536000, genericAddress, genericAddress]);
  console.log(`${Vester_artifact.contractName} contract deployment fee:`, Vester_Fee.toNumber());

  const TotalFee = WETH_Fee.add(Factory_Fee).add(Router_Fee).add(Masterchef_Fee).add(Vester_Fee);
  console.log("Total Fee:", TotalFee.toNumber());
 
};

export default estimateGas;