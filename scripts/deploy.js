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

    const dTagCommonContact  = await hre.ethers.getContractFactory("dTagCommon");
    const dTagCommon = await dTagCommonContact.deploy();
    await dTagCommon.deployed();
    console.log("dTagCommonContact deployed to:", dTagCommon.address);

    const dTagUtilsContract = await hre.ethers.getContractFactory("dTagUtils");
    const dTagUtils = await dTagUtilsContract.deploy();
    await dTagUtils.deployed();
    console.log("dTagUtils deployed to:", dTagUtils.address);

    const dTagContract = await hre.ethers.getContractFactory("dTag", {
        libraries:{
            dTagUtils:dTagUtils.address,
            dTagCommon:dTagCommon.address
        }
    });
  const dTag = await dTagContract.deploy(storage.address);
  await dTag.deployed();
  console.log("dTag deployed to:", dTag.address);
  await setStorageAccessor(storage.address, dTag.address);
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
