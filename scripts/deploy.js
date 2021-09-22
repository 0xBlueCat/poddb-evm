// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// import ethers from "ethers";
// import storage from "../artifacts/contracts/Storage.sol/Storage.json";
const ethers = require("ethers");
const storage = require("../artifacts/contracts/Storage.sol/Storage.json")
const driver = require("../artifacts/contracts/Driver.sol/Driver.json")
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

    const validatorContract = await hre.ethers.getContractFactory("Validator");
    const validator = await validatorContract.deploy();
    await validator.deployed();
    console.log("validator deployed to:", validator.address);

    const driverContract = await hre.ethers.getContractFactory("Driver");
    const driver = await driverContract.deploy(storage.address);
    await driver.deployed();
    console.log("driver deployed to:", driver.address);
    await setStorageAccessor(storage.address, driver.address);

   const podDBContract = await hre.ethers.getContractFactory("PodDB",{
        libraries:{
            Validator:validator.address
        }
    });
   const podDB = await podDBContract.deploy(driver.address);
   await podDB.deployed();
   console.log("poddb deployed to:", podDB.address);
   await changeOwner(driver.address, podDB.address);
}

const provider = new ethers.providers.JsonRpcProvider(
    "http://127.0.0.1:8545"
);
const wallet = new ethers.Wallet(
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    provider
);

async function setStorageAccessor(storageAddress, dTagAddress){
    const contact = new ethers.Contract(storageAddress, storage.abi, provider).connect(
        wallet
    );
    const iface = new ethers.utils.Interface(storage.abi);

    const tx = await contact.addAccessor(dTagAddress);
    await tx.wait();

    const rcp = await provider.getTransactionReceipt(tx.hash);
    const parseLogs = await iface.parseLog(rcp.logs[0]);
    console.log("ParsedLogs:", JSON.stringify(parseLogs, undefined, 2));
}

async function changeOwner(driverAddress, owner){
    const contact = new ethers.Contract(driverAddress, driver.abi, provider).connect(
        wallet
    );
    const iface = new ethers.utils.Interface(driver.abi);
    const tx = await contact.transferOwnership(owner);
    await tx.wait();

    const rcp = await provider.getTransactionReceipt(tx.hash);
    const parseLogs = await iface.parseLog(rcp.logs[0]);
    console.log("ParsedLogs:", JSON.stringify(parseLogs, undefined, 2));

    const curOwner = await contact.owner();
    console.log("Driver owner:", curOwner);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
