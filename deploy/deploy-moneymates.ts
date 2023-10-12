import { Wallet } from "zksync-web3";
// import * as ethers from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";

// load env file
import dotenv from "dotenv";
dotenv.config();

// load wallet private key from env file
const PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY || "";
const FEES_RECIPIENT = process.env.FEES_RECIPIENT || "";

if (!PRIVATE_KEY)
  throw "⛔️ Private key not detected! Add it to the .env file!";
if (!FEES_RECIPIENT)
  throw "⛔️ FEES RECIPIENT not detected! Add it to the .env file!";

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for the MoneyMates contract`);

  // Initialize the wallet.
  const wallet = new Wallet(PRIVATE_KEY);

  // Create deployer object and load the artifact of the contract you want to deploy.
  const deployer = new Deployer(hre, wallet);
  const contract = await deployer.loadArtifact("MoneyMates");

  const moneymates = await hre.zkUpgrades.deployProxy(deployer.zkWallet, contract, [FEES_RECIPIENT], { initializer: "initialize" });

  const MM = await moneymates.deployed()

  // Show the contract info.
  const contractAddress = MM.address;
  console.log(`${contract.contractName} was deployed to ${contractAddress}`);

  // // verify contract for tesnet & mainnet
  // if (process.env.NODE_ENV != "test") {
  //   // Contract MUST be fully qualified name (e.g. path/sourceName:contractName)
  //   const contractFullyQualifedName = "contracts/MoneyMates.sol:MoneyMates";

  //   // Verify contract programmatically
  //   const verificationId = await hre.run("verify:verify", {
  //     address: contractAddress,
  //     contract: contractFullyQualifedName,
  //     constructorArguments: [],
  //     bytecode: contract.bytecode,
  //   });
  // } else {
  //   console.log(`Contract not verified, deployed locally.`);
  // }
}
