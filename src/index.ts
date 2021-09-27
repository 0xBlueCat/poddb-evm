import { ethers } from "ethers";
import podDB from "../artifacts/contracts/PodDB.sol/PodDB.json";
import storage from "../artifacts/contracts/Storage.sol/Storage.json";

import {
  AgentType,
  buildTagObject,
  NoTagAgent,
  TagAgentBuilder,
  TagClassFieldBuilder,
  TagFieldType,
  TagObject,
} from "./PodDB";
import { WriteBuffer } from "./WriteBuffer";

const storageAddress = "0xdb54fa574a3e8c6aC784e1a5cdB575A737622CFf";
const podDBAddress = "0xDC0a0B1Cd093d321bD1044B5e0Acb71b525ABb6b";

const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");
const wallet = new ethers.Wallet(
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  provider
);
// const provider = new ethers.providers.JsonRpcProvider(
//   process.env.RINKEBY_URL || "http://127.0.0.1:8545"
// );
// const wallet = new ethers.Wallet(
//   process.env.PRIVATE_KEY ||
//     "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
//   provider
// );

const contact = new ethers.Contract(podDBAddress, podDB.abi, provider).connect(
  wallet
);
const iface = new ethers.utils.Interface(podDB.abi);

async function newTagClass(): Promise<string> {
  const tagFields = new TagClassFieldBuilder()
    .put("count", TagFieldType.Uint8)
    .put("texts", TagFieldType.Bytes)
    .build();
  const dTagTx = await contact.newTagClass(
    "DeMetaTexts",
    tagFields,
    "DeMetaTexts",
    0,
    0,
    NoTagAgent
  );
  console.log("dTagTx:", JSON.stringify(dTagTx, undefined, 2));
  //
  await dTagTx.wait();
  // const tx = await provider.getTransaction(dTagTx.hash);
  // console.log(JSON.stringify(tx, undefined, 2));

  const rcp = await provider.getTransactionReceipt(dTagTx.hash);
  console.log("Receipt:", JSON.stringify(rcp, undefined, 2));
  const parseLogs = await iface.parseLog(rcp.logs[0]);
  console.log("ParsedLogs:", JSON.stringify(parseLogs.args, undefined, 2));

  return parseLogs.args[0];
}

async function newDeMetaLootTag(): Promise<void> {
  //new profileTagClass
  let tagFields = new TagClassFieldBuilder()
    .put("profile", TagFieldType.String)
    .build();
  let tx = await contact.newTagClass(
    "DeMetaProfile",
    tagFields,
    "Profile of DeMetaLoot",
    0,
    0,
    NoTagAgent
  );
  await tx.wait();
  let rcp = await provider.getTransactionReceipt(tx.hash);
  let parseLogs = await iface.parseLog(rcp.logs[0]);
  console.log("ParsedLogs:", JSON.stringify(parseLogs.args, undefined, 2));

  //new textTagClass
  tagFields = new TagClassFieldBuilder()
    .put("count", TagFieldType.Uint8)
    .put("texts", TagFieldType.Bytes)
    .build();
  tx = await contact.newTagClass(
    "DeMetaTexts",
    tagFields,
    "Texts of DeMeteLoot",
    0,
    0,
    new TagAgentBuilder(
      AgentType.Address,
      "0xfc073209b7936A771F77F63D42019a3a93311869"
    ).build()
  );
  await tx.wait();
  rcp = await provider.getTransactionReceipt(tx.hash);
  parseLogs = await iface.parseLog(rcp.logs[0]);
  console.log("ParsedLogs:", JSON.stringify(parseLogs.args, undefined, 2));

  //new tokenURI tagClass
  tagFields = new TagClassFieldBuilder()
    .put("profile", TagFieldType.String)
    .build();
  tx = await contact.newTagClass(
    "DeMetaTokenURI",
    tagFields,
    "TokenURL of DeMeteLoot",
    0,
    0,
    NoTagAgent
  );
  await tx.wait();
  rcp = await provider.getTransactionReceipt(tx.hash);
  parseLogs = await iface.parseLog(rcp.logs[0]);
  console.log("ParsedLogs:", JSON.stringify(parseLogs.args, undefined, 2));
}

async function updateTagClass(tagClassId: string) {
  const tagClass = await contact.getTagClass(tagClassId);
  const tagClassInfo = await contact.getTagClassInfo(tagClassId);
  console.log("TagClass:", JSON.stringify(tagClass, undefined, 2));
  console.log("TagClassInfo:", JSON.stringify(tagClassInfo, undefined, 2));

  const tx = await contact.updateTagClass(
    tagClassId,
    tagClass[2],
    0,
    0,
    new TagAgentBuilder(
      AgentType.Address,
      "0xfc073209b7936A771F77F63D42019a3a93311869"
    ).build()
  );
  await tx.wait();
  const rcp = await provider.getTransactionReceipt(tx.hash);
  console.log("Receipt:", JSON.stringify(rcp, undefined, 2));
  const parseLogs = await iface.parseLog(rcp.logs[0]);
  console.log("ParsedLogs:", JSON.stringify(parseLogs.args, undefined, 2));

  return parseLogs.args[0];
}

async function getTagClass(tagClassId: string) {
  const tagClass = await contact.getTagClass(tagClassId);
  const tagClassInfo = await contact.getTagClassInfo(tagClassId);
  console.log("TagClass:", JSON.stringify(tagClass, undefined, 2));
  console.log("TagClassInfo:", JSON.stringify(tagClassInfo, undefined, 2));
}

async function getTagById(tagId: string): Promise<void> {
  const tx = await contact.getTagById(tagId);
  console.log("Tag:", JSON.stringify(tx, undefined, 2));
}

async function getTag(tagClassId: string, object: TagObject): Promise<void> {
  const tx = await contact.getTag(tagClassId, object);
  console.log("Tag:", JSON.stringify(tx, undefined, 2));
}

async function hasTag(tagClassId: string, tagObject: [string, string]) {
  const tx = await contact.hasTag(tagClassId, tagObject);
  console.log("HasTag:", JSON.stringify(tx, undefined, 2));
}

async function setTag(tagClassId: string) {
  const texts = new WriteBuffer()
    .writeBytes(ethers.utils.toUtf8Bytes("Warhammer"))
    .writeBytes(ethers.utils.toUtf8Bytes("Divine Robe"))
    .writeBytes(ethers.utils.toUtf8Bytes("Ancient"))
    .writeBytes(ethers.utils.toUtf8Bytes("Helm Ornate"))
    .writeBytes(ethers.utils.toUtf8Bytes("Greaves"))
    .writeBytes(ethers.utils.toUtf8Bytes("Gauntlets"))
    .getBytes();

  const data = new WriteBuffer().writeUint8(6).writeBytes(texts).getBytes();
  const dTagTx = await contact.setTag(
    tagClassId,
    buildTagObject("0x1848875EBafcB36662A674b58b2474874BD823d2", 2),
    data
  );
  // console.log("dTagTx:", JSON.stringify(dTagTx, undefined, 2));
  await dTagTx.wait();
  const rcp = await provider.getTransactionReceipt(dTagTx.hash);
  // console.log("Receipt:", JSON.stringify(rcp, undefined, 2));
  const parseLogs = await iface.parseLog(rcp.logs[0]);
  console.log("ParsedLogs:", JSON.stringify(parseLogs.args, undefined, 2));
}

async function deleteTag(tagId: string) {
  const dTagTx = await contact.deleteTag(tagId);
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
  const iface = new ethers.utils.Interface(podDB.abi);
  const data = new WriteBuffer().writeString("Hello").writeUint8(24).getBytes();
  const dTagTx = await contact.getTagClass(
    "0x496a431cd126621347fc56e708357c839ceed485"
  );
  // const dTagTx = await contact.getTag("0x07aea0a7978fddcde5ee567f66772d3ec24ee0a6");
  // const dTagTx = await contact.newTag(
  //   "0xb42f1e30e04897972a96f52fa66364663ccb5d2e",
  //   buildTagObject("0xEc929115b0a4A687BAaa81CA760cbF15380F7D0C"),
  //   data
  // );
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
  console.log("tagSchemaId:", tagSchemaId);
  // await newDeMetaLootTag();
  // const tagSchemaId = "0xbb7bb6518584b668031ef3cf0391954b0ef96b83";
  await setTag(tagSchemaId);
  // await updateTagClass(tagSchemaId);
  // await deleteTag("0x905671c1970fae55420150a64282f01db6461b89");
  // await testDTag();
  // await getTagClass(tagSchemaId);
  // await getTagById("0xfc94672e4401de4bc0738873cdafbfb27d5283af");
  // await getTag(
  //   tagSchemaId,
  //   buildTagObject("0x666432Ccb747B2220875cE185f487Ed53677faC9", 1)
  // );
  // await hasTag(
  //   tagSchemaId,
  //   buildTagObject("0x666432Ccb747B2220875cE185f487Ed53677faC9", 1)
  // );
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
