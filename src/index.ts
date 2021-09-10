import { ethers } from "ethers";
import dTag from "../artifacts/contracts/dTag.sol/dTag.json";
import { TagFieldType, TagSchemaFieldBuilder } from "./dTag";
import {WriteBuffer} from "./WriteBuffer";

const dTagAddress = "0x36b58F5C1969B7b6591D752ea6F5486D069010AB";

async function testDTag(): Promise<void> {
  const provider = new ethers.providers.JsonRpcProvider(
    "http://127.0.0.1:8545"
  );
  const wallet = new ethers.Wallet(
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    provider
  );
  const contact = new ethers.Contract(dTagAddress, dTag.abi, provider).connect(
    wallet
  );
  const iface = new ethers.utils.Interface(dTag.abi);
  const data = new WriteBuffer().writeString("Hello").writeUint8(24).getBytes();
  // const dTagTx = await contact.getTagSchema("0x068d4ab4405464d098eaed16f6f125cf822c8943");
  const dTagTx = await contact.addTagToAddress("0x85c4a441f09442a99a50d11dca774745909bb48f", "0xEc929115b0a4A687BAaa81CA760cbF15380F7D0C", data);
  const tagFields = new TagSchemaFieldBuilder()
    .put("name", TagFieldType.String)
    .put("age", TagFieldType.Uint8)
    .build();
  // const dTagTx = await contact.createTagSchema(
  //   "PersonTag",
  //   tagFields,
  //   "Person Tag",
  //   true,
  //   0
  // );
  console.log("dTagTx:", JSON.stringify(dTagTx, undefined, 2));
  //
  await dTagTx.wait();
  const tx = await provider.getTransaction(dTagTx.hash)
  console.log(JSON.stringify(tx, undefined,2));

  const rcp = await provider.getTransactionReceipt(dTagTx.hash);
  console.log("Receipt:", JSON.stringify(rcp, undefined, 2));
  const parseLogs = await iface.parseLog(rcp.logs[0]);
  console.log("ParsedLogs:", JSON.stringify(parseLogs,undefined,2));

  // const tagSchemaId = '0x082992df439c2175e02442dc4ee2b01610060dfb';
  // const tagSchema = await contact.getTagSchema(tagSchemaId);
  // console.log("TagSchema:", JSON.stringify(tagSchema, undefined, 2));
}

async function main(): Promise<void> {
  await testDTag();
//   const tagFields = new TagSchemaFieldBuilder()
//       .put("name", TagFieldType.String)
//       .put("age", TagFieldType.Uint8)
//       .build();
//   console.log(tagFields);
//   const data = new WriteBuffer().writeString("Hello").writeUint8(24).getBytes();
// console.log(data)
}

void main();
