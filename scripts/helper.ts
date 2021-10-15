import { ethers } from "ethers";
import storage from "../artifacts/contracts/Storage.sol/Storage.json";
import driver from "../artifacts/contracts/Driver.sol/Driver.json";
const hre = require("hardhat");

export interface PodDBDeployResult{
    StorageAddress:string,
    DriverAddress:string,
    PodDBAddress:string,
}

export async function deployStorage():Promise<string>{
    const storageContract = await hre.ethers.getContractFactory("contracts/Storage.sol:Storage");
    const storage = await storageContract.deploy();
    await storage.deployed();
    console.log("Storage deployed to:", storage.address)
    return storage.address;
}

export async function deployDriver(storageAddress:string):Promise<string>{
    const driverContract = await hre.ethers.getContractFactory("Driver");
    const driver = await driverContract.deploy(storageAddress);
    await driver.deployed();
    console.log("Driver deployed to:", driver.address)
    return driver.address
}

export async function deployPodDB(driverAddress:string):Promise<string>{
    const validatorContract = await hre.ethers.getContractFactory("Validator");
    const validator = await validatorContract.deploy();
    await validator.deployed();
    console.log("Validator deployed to:", validator.address)

    const podDBContract = await hre.ethers.getContractFactory("PodDB",{
        libraries:{
            Validator:validator.address
        }
    });
    const podDB = await podDBContract.deploy(driverAddress);
    await podDB.deployed();
    console.log("PodDB deployed to:", podDB.address)
    return podDB.address;
}

export async function deploy():Promise<PodDBDeployResult>{
    const storage = await deployStorage();
    const driver = await deployDriver(storage);
    const podDB = await deployPodDB(driver);

    await setStorageAccessor(storage, driver);
    await changeOwner(driver, podDB);

    return {
        StorageAddress:storage,
        DriverAddress:driver,
        PodDBAddress:podDB
    }
}

export async function setStorageAccessor(storageAddress:string, driverAddress:string){
    const contact = new ethers.Contract(storageAddress, storage.abi, hre.ethers.provider).connect(await getSigner());
    const tx = await contact.addAccessor(driverAddress);
    await tx.wait();

    // const rcp = await hre.ethers.provider.getTransactionReceipt(tx.hash);
    // const iface = new ethers.utils.Interface(storage.abi);
    // const parseLogs = await iface.parseLog(rcp.logs[0]);
    // console.log("ParsedLogs:", JSON.stringify(parseLogs.args, undefined, 2));
    console.log("SetStorageAccessor success.");
}

export async function changeOwner(driverAddress, owner){
    const contact = new ethers.Contract(driverAddress, driver.abi, hre.ethers.provider).connect(await getSigner());
    const tx = await contact.transferOwnership(owner);
    await tx.wait();

    // const rcp = await hre.ethers.provider.getTransactionReceipt(tx.hash);
    // const iface = new hre.ethers.utils.Interface(driver.abi);
    // const parseLogs = await iface.parseLog(rcp.logs[0]);
    // console.log("ParsedLogs:", JSON.stringify(parseLogs.args, undefined, 2));
    console.log("ChangeOwner success.");
}

export async function getSigner():Promise<ethers.Signer>{
    if(hre.network.name === "localhost" || hre.network.name === "hardhat"){
        const accounts =  await hre.ethers.getSigners();
        return accounts[0];
    }
    return new ethers.Wallet(
        hre.network.config.accounts[0],
        hre.ethers.provider
    );
}
