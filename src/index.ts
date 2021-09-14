import { ethers } from "ethers";
import dTag from "../artifacts/contracts/PodDB.sol/PodDB.json";
import storage from "../artifacts/contracts/Storage.sol/Storage.json";
import {
  AgentType, buildTagObject,
  NoTagAgent,
  TagAgentBuilder,
  TagFieldType,
  TagClassFieldBuilder,
} from "./PodDB";
import { WriteBuffer } from "./WriteBuffer";
import { ReadBuffer } from "./ReadBuffer";

const storageAddress = "0xD42912755319665397FF090fBB63B1a31aE87Cee";
const podDBAddress = "0x00CAC06Dd0BB4103f8b62D280fE9BCEE8f26fD59";

const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");
const wallet = new ethers.Wallet(
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  provider
);
const contact = new ethers.Contract(podDBAddress, dTag.abi, provider).connect(
  wallet
);
const iface = new ethers.utils.Interface(dTag.abi);

async function newTagClass(): Promise<string> {
  const tagFields = new TagClassFieldBuilder()
    .put("name", TagFieldType.String)
    .put("age", TagFieldType.Uint8)
    .build();
  const dTagTx = await contact.newTagClass(
    "PersonTag",
    tagFields,
    "Person Tag",
    0,
    0,
    NoTagAgent
  );
  // console.log("dTagTx:", JSON.stringify(dTagTx, undefined, 2));
  //
  await dTagTx.wait();
  // const tx = await provider.getTransaction(dTagTx.hash);
  // console.log(JSON.stringify(tx, undefined, 2));

  const rcp = await provider.getTransactionReceipt(dTagTx.hash);
  console.log("Receipt:", JSON.stringify(rcp, undefined, 2));
  const parseLogs = await iface.parseLog(rcp.logs[0]);
  console.log("ParsedLogs:", JSON.stringify(parseLogs.args, undefined, 2));

  return parseLogs.args[1];
}

async function newTag(tagClassId: string) {
  const data = new WriteBuffer().writeString("Hello").writeUint8(24).getBytes();
  const dTagTx = await contact.newTag(
    tagClassId,
    buildTagObject("0xEc929115b0a4A687BAaa81CA760cbF15380F7D0C"),
    data
  );
  // console.log("dTagTx:", JSON.stringify(dTagTx, undefined, 2));
  await dTagTx.wait();
  const rcp = await provider.getTransactionReceipt(dTagTx.hash);
  // console.log("Receipt:", JSON.stringify(rcp, undefined, 2));
  const parseLogs = await iface.parseLog(rcp.logs[0]);
  console.log("ParsedLogs:", JSON.stringify(parseLogs.args, undefined, 2));
}

async function testStorage(): Promise<void> {
  const contact = new ethers.Contract(
    storageAddress,
    storage.abi,
    provider
  ).connect(wallet);
  const iface = new ethers.utils.Interface(storage.abi);
  const tx = await contact.get("0x2adfa6093dc8f9a23cf52aba05b31347c4829b2c");
  console.log("==", tx);
}

async function testDTag(): Promise<void> {
  const iface = new ethers.utils.Interface(dTag.abi);
  const data = new WriteBuffer().writeString("Hello").writeUint8(24).getBytes();
  // const dTagTx = await contact.get("0x2ad251bdaae0430e5e5430a80710da19e5b2671c");
  const dTagTx = await contact.newTag("0xb42f1e30e04897972a96f52fa66364663ccb5d2e", buildTagObject("0xEc929115b0a4A687BAaa81CA760cbF15380F7D0C"), data);
  // const tagFields = new TagSchemaFieldBuilder()
  //   .put("name", TagFieldType.String)
  //   .put("age", TagFieldType.Uint8)
  //   .build();
  // const dTagTx = await contact.newTagClass(
  //   "PersonTag",
  //   tagFields,
  //   "Person Tag",
  //   false,
  //   true,
  //   false,
  //   0,
  //   NoTagAgent
  // );
  console.log("dTagTx:", JSON.stringify(dTagTx, undefined, 2));
  //
  // await dTagTx.wait();
  // const tx = await provider.getTransaction(dTagTx.hash);
  // console.log(JSON.stringify(tx, undefined, 2));

  // const rcp = await provider.getTransactionReceipt(dTagTx.hash);
  // console.log("Receipt:", JSON.stringify(rcp, undefined, 2));
  // const parseLogs = await iface.parseLog(rcp.logs[0]);
  // console.log("ParsedLogs:", JSON.stringify(parseLogs, undefined, 2));

  // const tagSchemaId = '0x082992df439c2175e02442dc4ee2b01610060dfb';
  // const tagSchema = await contact.getTagSchema(tagSchemaId);
  // console.log("TagSchema:", JSON.stringify(tagSchema, undefined, 2));
}

async function main(): Promise<void> {
  const tagSchemaId = await newTagClass();
  await newTag(tagSchemaId);
  // await testDTag();

  // await testStorage();
  //   const tagFields = new TagSchemaFieldBuilder()
  //       .put("name", TagFieldType.String)
  //       .put("age", TagFieldType.Uint8)
  //       .build();
  //   console.log(tagFields);
  //   const data = new WriteBuffer().writeString("Hello").writeUint8(24).getBytes();
  // console.log(data)
}

void main();
