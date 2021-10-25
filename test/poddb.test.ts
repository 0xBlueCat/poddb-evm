import * as chai from "chai";
import "mocha";
import { deploy, PodDBDeployResult } from "../scripts/helper";
import poddb from "../artifacts/contracts/PodDB.sol/PodDB.json";
import { ethers } from "ethers";
import * as sdk from "poddb-sdk-ts";
import {
  buildTagObject,
  DefaultTagAgent,
  DefaultTagFlags,
  TagData,
  TagFieldType,
  WriteBuffer,
} from "poddb-sdk-ts";
import { before } from "mocha";

const hre = require("hardhat");
const expect = chai.expect;

let deployResult: PodDBDeployResult;
let signers: ethers.Signer[];
let podDBC: sdk.PodDBContact;

describe("PodDB", async function () {
  this.timeout(10000);

  before(async () => {
    //deploy contract
    deployResult = await deploy();

    signers = await hre.ethers.getSigners();
    const defaultSigner = signers[0];

    podDBC = new sdk.PodDB(hre.ethers.provider)
      .connectPodDBContract(deployResult.PodDBAddress, poddb.abi)
      .connectSigner(defaultSigner);
  });

  it("tagFieldType", async function () {
    const fieldBuilder = new sdk.TagClassFieldBuilder();
    fieldBuilder.put("f1", sdk.TagFieldType.Bool);
    fieldBuilder.put("f2", sdk.TagFieldType.Uint256);
    fieldBuilder.put("f3", sdk.TagFieldType.Uint8);
    fieldBuilder.put("f4", sdk.TagFieldType.Uint16);
    fieldBuilder.put("f5", sdk.TagFieldType.Uint32);
    fieldBuilder.put("f6", sdk.TagFieldType.Uint64);
    fieldBuilder.put("f7", sdk.TagFieldType.Bytes1);
    fieldBuilder.put("f8", sdk.TagFieldType.Bytes2);
    fieldBuilder.put("f9", sdk.TagFieldType.Bytes3);
    fieldBuilder.put("f10", sdk.TagFieldType.Bytes4);
    fieldBuilder.put("f11", sdk.TagFieldType.Bytes8);
    fieldBuilder.put("f12", sdk.TagFieldType.Bytes20);
    fieldBuilder.put("f13", sdk.TagFieldType.Bytes32);
    fieldBuilder.put("f14", sdk.TagFieldType.Address);
    fieldBuilder.put("f15", sdk.TagFieldType.Bytes);
    fieldBuilder.put("f16", sdk.TagFieldType.String);
    fieldBuilder.put("f17", sdk.TagFieldType.Bool, true);
    fieldBuilder.put("f18", sdk.TagFieldType.Uint256, true);
    fieldBuilder.put("f19", sdk.TagFieldType.Uint8, true);
    fieldBuilder.put("f20", sdk.TagFieldType.Uint16, true);
    fieldBuilder.put("f21", sdk.TagFieldType.Uint32, true);
    fieldBuilder.put("f22", sdk.TagFieldType.Uint64, true);
    fieldBuilder.put("f23", sdk.TagFieldType.Bytes1, true);
    fieldBuilder.put("f24", sdk.TagFieldType.Bytes2, true);
    fieldBuilder.put("f25", sdk.TagFieldType.Bytes3, true);
    fieldBuilder.put("f26", sdk.TagFieldType.Bytes4, true);
    fieldBuilder.put("f27", sdk.TagFieldType.Bytes8, true);
    fieldBuilder.put("f28", sdk.TagFieldType.Bytes20, true);
    fieldBuilder.put("f29", sdk.TagFieldType.Bytes32, true);
    fieldBuilder.put("f30", sdk.TagFieldType.Address, true);
    fieldBuilder.put("f31", sdk.TagFieldType.Bytes, true);
    fieldBuilder.put("f32", sdk.TagFieldType.String, true);

    const tagClassTx = await podDBC.newTagClass(
      "tagFieldTypeTest",
      "f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11,f12,f13,f14,f15,f16,f17,f18,f19,f20,f21,f22,f23,f24,f25,f26,f27,f28,f29,f30,f31,f32",
      fieldBuilder.getFieldTypes(),
      "tagFieldType",
      DefaultTagFlags,
      0,
      DefaultTagAgent
    );
    tagClassTx.wait();

    const rcp = await hre.ethers.provider.getTransactionReceipt(
      tagClassTx.hash
    );
    const newTagClassEvt = await sdk.utils.parseNewTagClassEvent(rcp.logs[0]);
    console.log(
      "NewTagClassEvt:",
      JSON.stringify(newTagClassEvt, undefined, 2)
    );

    const tagClass1 = await podDBC.getTagClass(newTagClassEvt.ClassId);
    expect(tagClass1!.ClassId).not.eq(
      "0x0000000000000000000000000000000000000000"
    );

    const tagClassInfo1 = await podDBC.getTagClassInfo(newTagClassEvt.ClassId);
    expect(tagClassInfo1!.ClassId).not.eq(
      "0x0000000000000000000000000000000000000000"
    );

    const tagObject = buildTagObject(
      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    );
    const tagData = new WriteBuffer()
      .writeBool(true)
      .writeUint256(
        ethers.BigNumber.from(
          "0x56ee41124a9af6b8590735ac413711e05faa6dc2b80f1e5d0cf7a5873ed36947"
        )
      )
      .writeUint8(10)
      .writeUint16(256)
      .writeUint32(345664)
      .writeUint64(32345452133)
      .writeBytes1("0x01")
      .writeBytes2("0x0102")
      .writeBytes3("0x010203")
      .writeBytes4("0x01020304")
      .writeBytes8("0x0102030405060708")
      .writeBytes20("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
      .writeBytes32(
        "0x56ee41124a9af6b8590735ac413711e05faa6dc2b80f1e5d0cf7a5873ed36947"
      )
      .writeAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
      .writeBytes("0x01020304")
      .writeString("Hello, world!")
      .writeArray([true, false], TagFieldType.Bool)
      .writeArray(
        [
          ethers.BigNumber.from(
            "0x56ee41124a9af6b8590735ac413711e05faa6dc2b80f1e5d0cf7a5873ed36947"
          ),
        ],
        TagFieldType.Uint256
      )
      .writeArray([2, 4, 6, 8], TagFieldType.Uint8)
      .writeArray([12, 14, 16, 18], TagFieldType.Uint16)
      .writeArray([200, 400, 600, 800], TagFieldType.Uint32)
      .writeArray([1200, 1400, 1600, 1800], TagFieldType.Uint64)
      .writeArray(["0x01", "0x02"], TagFieldType.Bytes1)
      .writeArray(["0x0102", "0x0203"], TagFieldType.Bytes2)
      .writeArray(["0x010203", "0x020304"], TagFieldType.Bytes3)
      .writeArray(["0x01020304", "0x02030405"], TagFieldType.Bytes4)
      .writeArray(["0x0102030405060708"], TagFieldType.Bytes8)
      .writeArray(
        ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"],
        TagFieldType.Bytes20
      )
      .writeArray(
        ["0x56ee41124a9af6b8590735ac413711e05faa6dc2b80f1e5d0cf7a5873ed36947"],
        TagFieldType.Bytes32
      )
      .writeArray(
        ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"],
        TagFieldType.Address
      )
      .writeArray(
        [
          "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
          "0x56ee41124a9af6b8590735ac413711e05faa6dc2b80f1e5d0cf7a5873ed36947",
        ],
        TagFieldType.Bytes
      )
      .writeArray(["Hello", "World"], TagFieldType.String)
      .getBytes();

    const tagTx = await podDBC.setTag(
      newTagClassEvt.ClassId,
      tagObject,
      tagData
    );
    tagTx.wait();
    const rcp1 = await hre.ethers.provider.getTransactionReceipt(tagTx.hash);
    const setTagEvt = await sdk.utils.parseSetTagEvent(rcp1.logs[0]);
    console.log("SetTagEvt:", JSON.stringify(setTagEvt, undefined, 2));

    const data = new TagData(
      newTagClassEvt.FieldNames,
      newTagClassEvt.FieldTypes,
      setTagEvt.Data
    );
    console.log("f1:", data.get("f1")!.getBool());
    console.log("f2:", data.get("f2")!.getNumber().toString());
    console.log("f3:", data.get("f3")!.getNumber().toString());
    console.log("f4:", data.get("f4")!.getNumber().toString());
    console.log("f5:", data.get("f5")!.getNumber().toString());
    console.log("f6:", data.get("f6")!.getNumber().toString());
    console.log("f7:", data.get("f7")!.getString());
    console.log("f8:", data.get("f8")!.getString());
    console.log("f9:", data.get("f9")!.getString());
    console.log("f10:", data.get("f10")!.getString());
    console.log("f11:", data.get("f11")!.getString());
    console.log("f12:", data.get("f12")!.getString());
    console.log("f13:", data.get("f13")!.getString());
    console.log("f14:", data.get("f14")!.getString());
    console.log("f15:", data.get("f15")!.getString());
    console.log("f16:", data.get("f16")!.getString());
    console.log("f17:", data.get("f17")!.getBoolArray());
    console.log(
      "f18:",
      data
        .get("f18")!
        .getNumberArray()
        .map((value) => {
          return value.toString();
        })
    );
    console.log(
      "f19:",
      data
        .get("f19")!
        .getNumberArray()
        .map((value) => {
          return value.toString();
        })
    );
    console.log(
      "f20:",
      data
        .get("f20")!
        .getNumberArray()
        .map((value) => {
          return value.toString();
        })
    );
    console.log(
      "f21:",
      data
        .get("f21")!
        .getNumberArray()
        .map((value) => {
          return value.toString();
        })
    );
    console.log(
      "f22:",
      data
        .get("f22")!
        .getNumberArray()
        .map((value) => {
          return value.toString();
        })
    );
    console.log("f23:", data.get("f23")!.getStringArray());
    console.log("f24:", data.get("f24")!.getStringArray());
    console.log("f25:", data.get("f25")!.getStringArray());
    console.log("f26:", data.get("f26")!.getStringArray());
    console.log("f27:", data.get("f27")!.getStringArray());
    console.log("f28:", data.get("f28")!.getStringArray());
    console.log("f29:", data.get("f29")!.getStringArray());
    console.log("f30:", data.get("f30")!.getStringArray());
    console.log("f31:", data.get("f31")!.getStringArray());
    console.log("f32:", data.get("f32")!.getStringArray());
  });

  it("updateTagClass", async function () {
    const fieldBuilder = new sdk.TagClassFieldBuilder();
    fieldBuilder.put("f1", TagFieldType.String).put("f2", TagFieldType.Uint16);

    const tagClassTx = await podDBC.newTagClass(
      "updateTagClass",
      "f1,f2",
      fieldBuilder.getFieldTypes(),
      "updateTagClass test",
      sdk.DefaultTagFlags,
      0,
      sdk.DefaultTagAgent
    );
    tagClassTx.wait();

    const rcp = await hre.ethers.provider.getTransactionReceipt(
      tagClassTx.hash
    );
    const newTagClassEvt = await sdk.utils.parseNewTagClassEvent(rcp.logs[0]);
    console.log(
      "NewTagClassEvt:",
      JSON.stringify(newTagClassEvt, undefined, 2)
    );

    const newName = "newName";
    const newDesc = "newDesc";
    const updateInfoTx = await podDBC.updateTagClassInfo(
      newTagClassEvt.ClassId,
      newName,
      newDesc
    );
    updateInfoTx.wait();
    const updateInfoRcp = await hre.ethers.provider.getTransactionReceipt(
      updateInfoTx.hash
    );
    const newUpdateClassInfoEvt = await sdk.utils.parseUpdateTagClassInfoEvent(
      updateInfoRcp.logs[0]
    );
    console.log(
      "newUpdateClassInfoEvt:",
      JSON.stringify(newUpdateClassInfoEvt, undefined, 2)
    );

    const tagClassInfo1 = await podDBC.getTagClassInfo(newTagClassEvt.ClassId);
    expect(tagClassInfo1!.TagName).eq(newName);
    expect(tagClassInfo1!.Desc).eq(newDesc);

    const newOwner = await signers[1].getAddress();
    const newFlag = new sdk.TagFlagsBuilder().setMultiIssueFlag().build();
    const newAgent = new sdk.TagAgentBuilder(
      sdk.AgentType.Address,
      await signers[2].getAddress()
    ).build();
    const newExpired = 10;

    const updateTx = await podDBC.updateTagClass(
      newTagClassEvt.ClassId,
      newOwner,
      newFlag,
      newExpired,
      newAgent
    );
    updateTx.wait();

    const updateRcp = await hre.ethers.provider.getTransactionReceipt(
      updateTx.hash
    );
    const newUpdateClassEvt = await sdk.utils.parseUpdateTagClassEvent(
      updateRcp.logs[0]
    );
    console.log(
      "UpdateTagClassEvt:",
      JSON.stringify(newUpdateClassEvt, undefined, 2)
    );

    const tagClass1 = await podDBC.getTagClass(newUpdateClassEvt.ClassId);
    expect(tagClass1!.Owner).eq(newOwner);
    expect(tagClass1!.Agent[0]).eq(newAgent[0]);
    expect(tagClass1!.Agent[1]).eq(newAgent[1]);
    expect(tagClass1!.ExpiredTime).eq(newExpired);
  });

  it("updateTag", async function () {
    const fieldBuilder = new sdk.TagClassFieldBuilder();
    fieldBuilder.put("f1", TagFieldType.String);

    const tagClassTx = await podDBC.newTagClass(
      "testTagClass",
      "f1",
      fieldBuilder.getFieldTypes(),
      "testTagClass",
      sdk.DefaultTagFlags,
      0,
      sdk.DefaultTagAgent
    );
    tagClassTx.wait();

    const rcp = await hre.ethers.provider.getTransactionReceipt(
      tagClassTx.hash
    );
    const newTagClassEvt = await sdk.utils.parseNewTagClassEvent(rcp.logs[0]);
    console.log(
      "NewTagClassEvt:",
      JSON.stringify(newTagClassEvt, undefined, 2)
    );

    const tagObject = sdk.buildTagObject(await signers[1].getAddress());
    const data = new sdk.WriteBuffer().writeString("Hello").getBytes();
    const setTagTx = await podDBC.setTag(
      newTagClassEvt.ClassId,
      tagObject,
      data
    );
    const rcp1 = await hre.ethers.provider.getTransactionReceipt(setTagTx.hash);
    const setTagEvt = await sdk.utils.parseSetTagEvent(rcp1.logs[0]);
    console.log("SetTagEvt:", JSON.stringify(setTagEvt, undefined, 2));

    const tag1 = await podDBC.getTagByObject(setTagEvt.ClassId, tagObject);
    console.log("Tag:", JSON.stringify(tag1, undefined, 2));

    expect(setTagEvt.Data).eq(data);

    const newData = new sdk.WriteBuffer().writeString("World").getBytes();
    const setTagTx1 = await podDBC.setTag(
      newTagClassEvt.ClassId,
      tagObject,
      newData
    );
    const rcp2 = await hre.ethers.provider.getTransactionReceipt(
      setTagTx1.hash
    );
    const setTagEvt1 = await sdk.utils.parseSetTagEvent(rcp2.logs[0]);
    console.log("SetTagEvt:", JSON.stringify(setTagEvt1, undefined, 2));

    const tag2 = await podDBC.getTagByObject(setTagEvt.ClassId, tagObject);
    console.log("Tag:", JSON.stringify(tag2, undefined, 2));

    expect(setTagEvt1.Data).eq(newData);
  });

  it("tagAgent", async function () {
    const agentTagFieldBuilder = new sdk.TagClassFieldBuilder().put(
      "f1",
      TagFieldType.Bool
    );
    const agentTagClassTx = await podDBC.newTagClass(
      "agentTag",
      agentTagFieldBuilder.getFieldNames(),
      agentTagFieldBuilder.getFieldTypes(),
      "agent tag",
      sdk.DefaultTagFlags,
      0,
      sdk.DefaultTagAgent
    );
    agentTagClassTx.wait();
    const agentTagRcp = await hre.ethers.provider.getTransactionReceipt(
      agentTagClassTx.hash
    );
    const agentTagClassEvt = await sdk.utils.parseNewTagClassEvent(
      agentTagRcp.logs[0]
    );
    console.log(
      "AgentTagClassEvt:",
      JSON.stringify(agentTagClassEvt, undefined, 2)
    );

    const agentTagObject = sdk.buildTagObject(await signers[1].getAddress());
    const agentTagData = new sdk.WriteBuffer().writeBool(true).getBytes();
    const agentTagTx = await podDBC.setTag(
      agentTagClassEvt.ClassId,
      agentTagObject,
      agentTagData
    );
    agentTagTx.wait();

    const fieldBuilder = new sdk.TagClassFieldBuilder();
    fieldBuilder.put("f1", TagFieldType.String);

    const tagClassTx = await podDBC.newTagClass(
      "testTagClass",
      "f1",
      fieldBuilder.getFieldTypes(),
      "testTagClass",
      sdk.DefaultTagFlags,
      0,
      new sdk.TagAgentBuilder(
        sdk.AgentType.Tag,
        agentTagClassEvt.ClassId
      ).build()
    );
    tagClassTx.wait();

    const rcp = await hre.ethers.provider.getTransactionReceipt(
      tagClassTx.hash
    );
    const newTagClassEvt = await sdk.utils.parseNewTagClassEvent(rcp.logs[0]);
    console.log(
      "NewTagClassEvt:",
      JSON.stringify(newTagClassEvt, undefined, 2)
    );

    const tagObject = sdk.buildTagObject(await signers[1].getAddress(), 112);
    const data = new sdk.WriteBuffer().writeString("Hello").getBytes();

    //can setTag
    const podDbContract1 = podDBC.Contract().connect(signers[1]);
    const setTagTx = await podDbContract1.setTag(
      newTagClassEvt.ClassId,
      tagObject,
      data
    );
    const setTagRcp = await hre.ethers.provider.getTransactionReceipt(
      setTagTx.hash
    );
    const setTagEvt = await sdk.utils.parseSetTagEvent(setTagRcp.logs[0]);
    console.log("SetTagEvt:", JSON.stringify(setTagEvt, undefined, 2));
  });
});
