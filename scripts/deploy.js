// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// import ethers from "ethers";
// import storage from "../artifacts/contracts/Storage.sol/Storage.json";
const ethers = require("ethers");
const storage = require("../artifacts/contracts/Storage.sol/Storage.json")
const hre = require("hardhat");
async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  //
    const storageContact  = await hre.ethers.getContractFactory("contracts/Storage.sol:Storage");
    const storage = await storageContact.deploy();
    await storage.deployed();
    console.log("storageContact deployed to:", storage.address);

    const commonContact  = await hre.ethers.getContractFactory("Common");
    const common = await commonContact.deploy();
    await common.deployed();
    console.log("commonContact deployed to:", common.address);

    const utilsContract = await hre.ethers.getContractFactory("Utils");
    const utils = await utilsContract.deploy();
    await utils.deployed();
    console.log("utils deployed to:", utils.address);

    const podDBContract = await hre.ethers.getContractFactory("PodDB", {
        libraries:{
            Utils:utils.address,
            Common:common.address
        }
    });
  const podDB = await podDBContract.deploy(storage.address);
  await podDB.deployed();
  console.log("podDB deployed to:", podDB.address);
  await setStorageAccessor(storage.address, podDB.address);
}

async function setStorageAccessor(storageAddress, dTagAddress){
    const provider = new ethers.providers.JsonRpcProvider(
        "http://127.0.0.1:8545"
    );
    const wallet = new ethers.Wallet(
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
        provider
    );

    const contact = new ethers.Contract(storageAddress, storage.abi, provider).connect(
        wallet
    );
    const iface = new ethers.utils.Interface(storage.abi);

    const tx = await contact.addAccessor(dTagAddress);
    // console.log("storage tx:", JSON.stringify(tx, undefined, 2));
    //
    await tx.wait();

    const rcp = await provider.getTransactionReceipt(tx.hash);
    // console.log("Receipt:", JSON.stringify(rcp, undefined, 2));
    const parseLogs = await iface.parseLog(rcp.logs[0]);
    console.log("ParsedLogs:", JSON.stringify(parseLogs, undefined, 2));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
