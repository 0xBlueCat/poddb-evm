import * as chai from "chai";
import "mocha";
import { deploy, PodDBDeployResult } from "../scripts/helper";
import { ethers } from "ethers";
import * as podsdk from "poddb-sdk-ts";
import {
  DefaultTagClassFlags,
  DefaultTagFlags,
  TagFieldType,
  WriteBuffer,
} from "poddb-sdk-ts";
import { before } from "mocha";
import { TagClassFieldBuilder } from "poddb-sdk-ts/dist/utils/tagClassFieldBuilder";
import { TagAgentBuilder } from "poddb-sdk-ts/dist/utils/tagAgentBuilder";
import { buildTagObject } from "poddb-sdk-ts/dist/utils/utils";
import { TagDataParser } from "poddb-sdk-ts/dist/utils/tagDataParser";
import { TagFlagsBuilder } from "poddb-sdk-ts/dist/utils/tagFlags";

const hre = require("hardhat");
const expect = chai.expect;

let deployResult: PodDBDeployResult;
let signers: ethers.Signer[];
let podDBC: podsdk.PodDBContract;

describe("PodDB", async function () {
  this.timeout(10000);

  before(async () => {
    //deploy contract
    deployResult = await deploy();

    signers = await hre.ethers.getSigners();
    const defaultSigner = signers[0];

    const podDB = new podsdk.PodDB(hre.ethers.provider);
    podDBC = (
      await podDB.connectPodDBContract(deployResult.PodDBAddress)
    ).connectSigner(defaultSigner);
  });

  it("tagFieldType", async function () {
    const fieldBuilder = new TagClassFieldBuilder();
    fieldBuilder.put("f1", podsdk.TagFieldType.Bool);
    fieldBuilder.put("f2", podsdk.TagFieldType.Uint256);
    fieldBuilder.put("f3", podsdk.TagFieldType.Uint8);
    fieldBuilder.put("f4", podsdk.TagFieldType.Uint16);
    fieldBuilder.put("f5", podsdk.TagFieldType.Uint32);
    fieldBuilder.put("f6", podsdk.TagFieldType.Uint64);
    fieldBuilder.put("f7", podsdk.TagFieldType.Bytes1);
    fieldBuilder.put("f8", podsdk.TagFieldType.Bytes2);
    fieldBuilder.put("f9", podsdk.TagFieldType.Bytes3);
    fieldBuilder.put("f10", podsdk.TagFieldType.Bytes4);
    fieldBuilder.put("f11", podsdk.TagFieldType.Bytes8);
    fieldBuilder.put("f12", podsdk.TagFieldType.Bytes20);
    fieldBuilder.put("f13", podsdk.TagFieldType.Bytes32);
    fieldBuilder.put("f14", podsdk.TagFieldType.Address);
    fieldBuilder.put("f15", podsdk.TagFieldType.Bytes);
    fieldBuilder.put("f16", podsdk.TagFieldType.String);
    fieldBuilder.put("f17", podsdk.TagFieldType.Bool, true);
    fieldBuilder.put("f18", podsdk.TagFieldType.Uint256, true);
    fieldBuilder.put("f19", podsdk.TagFieldType.Uint8, true);
    fieldBuilder.put("f20", podsdk.TagFieldType.Uint16, true);
    fieldBuilder.put("f21", podsdk.TagFieldType.Uint32, true);
    fieldBuilder.put("f22", podsdk.TagFieldType.Uint64, true);
    fieldBuilder.put("f23", podsdk.TagFieldType.Bytes1, true);
    fieldBuilder.put("f24", podsdk.TagFieldType.Bytes2, true);
    fieldBuilder.put("f25", podsdk.TagFieldType.Bytes3, true);
    fieldBuilder.put("f26", podsdk.TagFieldType.Bytes4, true);
    fieldBuilder.put("f27", podsdk.TagFieldType.Bytes8, true);
    fieldBuilder.put("f28", podsdk.TagFieldType.Bytes20, true);
    fieldBuilder.put("f29", podsdk.TagFieldType.Bytes32, true);
    fieldBuilder.put("f30", podsdk.TagFieldType.Address, true);
    fieldBuilder.put("f31", podsdk.TagFieldType.Bytes, true);
    fieldBuilder.put("f32", podsdk.TagFieldType.String, true);

    const tagClassTx = await podDBC.newTagClass(
      "tagFieldTypeTest",
      fieldBuilder.getFieldNames(),
      fieldBuilder.getFieldTypes(),
      "tagFieldType"
    );
    tagClassTx.wait();

    const rcp = await hre.ethers.provider.getTransactionReceipt(
      tagClassTx.hash
    );
    const newTagClassEvt = await podDBC.parseNewTagClassLog(rcp.logs[0]);
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
    const setTagEvt = await podDBC.parseSetTagLog(rcp1.logs[0]);
    console.log("SetTagEvt:", JSON.stringify(setTagEvt, undefined, 2));

    expect(setTagEvt.Data).to.eq(
      await podDBC.getTagData(newTagClassEvt.ClassId, tagObject)
    );

    const dataParser = new TagDataParser(
      newTagClassEvt.FieldNames,
      newTagClassEvt.FieldTypes,
      setTagEvt.Data
    );
    console.log("f1:", dataParser.get("f1")!.getBool());
    console.log("f2:", dataParser.get("f2")!.getNumber().toString());
    console.log("f3:", dataParser.get("f3")!.getNumber().toString());
    console.log("f4:", dataParser.get("f4")!.getNumber().toString());
    console.log("f5:", dataParser.get("f5")!.getNumber().toString());
    console.log("f6:", dataParser.get("f6")!.getNumber().toString());
    console.log("f7:", dataParser.get("f7")!.getString());
    console.log("f8:", dataParser.get("f8")!.getString());
    console.log("f9:", dataParser.get("f9")!.getString());
    console.log("f10:", dataParser.get("f10")!.getString());
    console.log("f11:", dataParser.get("f11")!.getString());
    console.log("f12:", dataParser.get("f12")!.getString());
    console.log("f13:", dataParser.get("f13")!.getString());
    console.log("f14:", dataParser.get("f14")!.getString());
    console.log("f15:", dataParser.get("f15")!.getString());
    console.log("f16:", dataParser.get("f16")!.getString());
    console.log("f17:", dataParser.get("f17")!.getBoolArray());
    console.log(
      "f18:",
      dataParser
        .get("f18")!
        .getNumberArray()
        .map((value) => {
          return value.toString();
        })
    );
    console.log(
      "f19:",
      dataParser
        .get("f19")!
        .getNumberArray()
        .map((value) => {
          return value.toString();
        })
    );
    console.log(
      "f20:",
      dataParser
        .get("f20")!
        .getNumberArray()
        .map((value) => {
          return value.toString();
        })
    );
    console.log(
      "f21:",
      dataParser
        .get("f21")!
        .getNumberArray()
        .map((value) => {
          return value.toString();
        })
    );
    console.log(
      "f22:",
      dataParser
        .get("f22")!
        .getNumberArray()
        .map((value) => {
          return value.toString();
        })
    );
    console.log("f23:", dataParser.get("f23")!.getStringArray());
    console.log("f24:", dataParser.get("f24")!.getStringArray());
    console.log("f25:", dataParser.get("f25")!.getStringArray());
    console.log("f26:", dataParser.get("f26")!.getStringArray());
    console.log("f27:", dataParser.get("f27")!.getStringArray());
    console.log("f28:", dataParser.get("f28")!.getStringArray());
    console.log("f29:", dataParser.get("f29")!.getStringArray());
    console.log("f30:", dataParser.get("f30")!.getStringArray());
    console.log("f31:", dataParser.get("f31")!.getStringArray());
    console.log("f32:", dataParser.get("f32")!.getStringArray());
  });

  it("updateTagClass", async function () {
    const fieldBuilder = new TagClassFieldBuilder();
    fieldBuilder.put("f1", TagFieldType.String).put("f2", TagFieldType.Uint16);

    const tagClassTx = await podDBC.newTagClass(
      "updateTagClass",
      "f1,f2",
      fieldBuilder.getFieldTypes(),
      "updateTagClass test"
    );
    tagClassTx.wait();

    const rcp = await hre.ethers.provider.getTransactionReceipt(
      tagClassTx.hash
    );
    const newTagClassEvt = await podDBC.parseNewTagClassLog(rcp.logs[0]);
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
    const newUpdateClassInfoEvt = await podDBC.parseUpdateTagClassInfoLog(
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
    const newAgent = new TagAgentBuilder(
      podsdk.AgentType.Address,
      await signers[2].getAddress()
    ).build();

    const updateTx = await podDBC.updateTagClass(
      newTagClassEvt.ClassId,
      newOwner,
      newAgent,
      DefaultTagClassFlags
    );
    updateTx.wait();

    const updateRcp = await hre.ethers.provider.getTransactionReceipt(
      updateTx.hash
    );
    const newUpdateClassEvt = await podDBC.parseUpdateTagClassLog(
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
  });

  it("updateTag", async function () {
    const fieldBuilder = new TagClassFieldBuilder();
    fieldBuilder.put("f1", TagFieldType.String);

    const tagClassTx = await podDBC.newTagClass(
      "testTagClass",
      "f1",
      fieldBuilder.getFieldTypes(),
      "testTagClass"
    );
    tagClassTx.wait();

    const rcp = await hre.ethers.provider.getTransactionReceipt(
      tagClassTx.hash
    );
    const newTagClassEvt = await podDBC.parseNewTagClassLog(rcp.logs[0]);
    console.log(
      "NewTagClassEvt:",
      JSON.stringify(newTagClassEvt, undefined, 2)
    );

    const tagObject = buildTagObject(await signers[1].getAddress());
    const data = new podsdk.WriteBuffer().writeString("Hello").getBytes();
    const setTagTx = await podDBC.setTag(
      newTagClassEvt.ClassId,
      tagObject,
      data
    );
    setTagTx.wait();

    const rcp1 = await hre.ethers.provider.getTransactionReceipt(setTagTx.hash);
    const setTagEvt = await podDBC.parseSetTagLog(rcp1.logs[0]);
    console.log("SetTagEvt:", JSON.stringify(setTagEvt, undefined, 2));

    const tag1 = await podDBC.getTagByObject(setTagEvt.ClassId, tagObject);
    console.log("Tag:", JSON.stringify(tag1, undefined, 2));

    expect(setTagEvt.Data).eq(data);

    const newData = new podsdk.WriteBuffer().writeString("World").getBytes();
    const setTagTx1 = await podDBC.setTag(
      newTagClassEvt.ClassId,
      tagObject,
      newData
    );
    setTagTx1.wait();
    const rcp2 = await hre.ethers.provider.getTransactionReceipt(
      setTagTx1.hash
    );
    const setTagEvt1 = await podDBC.parseSetTagLog(rcp2.logs[0]);
    console.log("SetTagEvt:", JSON.stringify(setTagEvt1, undefined, 2));

    const tag2 = await podDBC.getTagByObject(setTagEvt.ClassId, tagObject);
    console.log("Tag:", JSON.stringify(tag2, undefined, 2));

    expect(setTagEvt1.Data).eq(newData);
  });

  it("tagAgent", async function () {
    const agentTagFieldBuilder = new TagClassFieldBuilder().put(
      "f1",
      TagFieldType.Bool
    );
    const agentTagClassTx = await podDBC.newTagClass(
      "agentTag",
      agentTagFieldBuilder.getFieldNames(),
      agentTagFieldBuilder.getFieldTypes(),
      "agent tag"
    );
    agentTagClassTx.wait();
    const agentTagRcp = await hre.ethers.provider.getTransactionReceipt(
      agentTagClassTx.hash
    );
    const agentTagClassEvt = await podDBC.parseNewTagClassLog(
      agentTagRcp.logs[0]
    );
    console.log(
      "AgentTagClassEvt:",
      JSON.stringify(agentTagClassEvt, undefined, 2)
    );

    const agentTagObject = buildTagObject(await signers[1].getAddress());
    const agentTagData = new podsdk.WriteBuffer().writeBool(true).getBytes();
    const agentTagTx = await podDBC.setTag(
      agentTagClassEvt.ClassId,
      agentTagObject,
      agentTagData
    );
    agentTagTx.wait();

    const fieldBuilder = new TagClassFieldBuilder();
    fieldBuilder.put("f1", TagFieldType.String);

    const tagClassTx = await podDBC.newTagClass(
      "testTagClass",
      "f1",
      fieldBuilder.getFieldTypes(),
      "testTagClass",
      {
        agent: new TagAgentBuilder(
          podsdk.AgentType.Tag,
          agentTagClassEvt.ClassId
        ).build(),
      }
    );
    tagClassTx.wait();

    const rcp = await hre.ethers.provider.getTransactionReceipt(
      tagClassTx.hash
    );
    const newTagClassEvt = await podDBC.parseNewTagClassLog(rcp.logs[0]);
    console.log(
      "NewTagClassEvt:",
      JSON.stringify(newTagClassEvt, undefined, 2)
    );

    const tagObject = buildTagObject(await signers[1].getAddress(), 112);
    const data = new podsdk.WriteBuffer().writeString("Hello").getBytes();

    //can setTag
    const podDbContract1 = podDBC.Contract().connect(signers[1]);
    const setTagTx = await podDbContract1.setTag(
      newTagClassEvt.ClassId,
      tagObject,
      data,
      0,
      DefaultTagFlags
    );
    const setTagRcp = await hre.ethers.provider.getTransactionReceipt(
      setTagTx.hash
    );
    const setTagEvt = await podDBC.parseSetTagLog(setTagRcp.logs[0]);
    console.log("SetTagEvt:", JSON.stringify(setTagEvt, undefined, 2));
  });

  it("deleteTag", async function () {
    const fieldBuilder = new TagClassFieldBuilder();
    fieldBuilder.put("f1", TagFieldType.String);

    const tagClassTx = await podDBC.newTagClass(
      "testTagClass",
      "f1",
      fieldBuilder.getFieldTypes(),
      "testTagClass"
    );
    tagClassTx.wait();
    const rcp = await hre.ethers.provider.getTransactionReceipt(
      tagClassTx.hash
    );
    const newTagClassEvt = await podDBC.parseNewTagClassLog(rcp.logs[0]);

    const tagObject = buildTagObject(await signers[1].getAddress());
    const data = new podsdk.WriteBuffer().writeString("Hello").getBytes();
    const setTagTx = await podDBC.setTag(
      newTagClassEvt.ClassId,
      tagObject,
      data
    );
    setTagTx.wait();

    let hasTag = await podDBC.hasTag(newTagClassEvt.ClassId, tagObject);
    expect(hasTag).to.true;

    const deleteTx = await podDBC.deleteTagByObject(
      newTagClassEvt.ClassId,
      tagObject
    );
    deleteTx.wait();

    hasTag = await podDBC.hasTag(newTagClassEvt.ClassId, tagObject);
    expect(hasTag).to.false;
  });

  it("tagWildcardFlag", async function () {
    const tagClassTx = await podDBC.newTagClass(
      "testTagClass",
      "",
      "0x",
      "testTagClass"
    );
    tagClassTx.wait();
    const rcp = await hre.ethers.provider.getTransactionReceipt(
      tagClassTx.hash
    );
    const newTagClassEvt = await podDBC.parseNewTagClassLog(rcp.logs[0]);

    const tagObject = buildTagObject(await signers[1].getAddress());
    const setTagTx = await podDBC.setTag(
      newTagClassEvt.ClassId,
      tagObject,
      "0x",
      {
        flags: new TagFlagsBuilder().setWildcardFlag().build(),
      }
    );
    setTagTx.wait();

    const setTagReceipt = await hre.ethers.provider.getTransactionReceipt(
      setTagTx.hash
    );
    const setTagLog = await podDBC.parseSetTagLog(setTagReceipt.logs[0]);
    console.log("SetTag:", JSON.stringify(setTagLog, undefined, 2));

    let hasTag = await podDBC.hasTag(newTagClassEvt.ClassId, tagObject);
    expect(hasTag).to.false;

    const tagObjectNft = buildTagObject(await signers[1].getAddress(), 1);
    hasTag = await podDBC.hasTag(newTagClassEvt.ClassId, tagObjectNft);

    const tag = await podDBC.getTagByObject(
      newTagClassEvt.ClassId,
      tagObjectNft
    );
    console.log(JSON.stringify(tag, undefined, 2));

    expect(hasTag).to.true;
  });

  it("tagBenchmark", async function () {
    const tagClassTx = await podDBC.newTagClass(
      "tagBenchmark",
      "",
      "0x",
      "tagBenchmark"
    );
    tagClassTx.wait();

    const newTagClassRcp = await hre.ethers.provider.getTransactionReceipt(
      tagClassTx.hash
    );
    console.log("newTagClass gasUsed:", newTagClassRcp.gasUsed.toNumber());
    const newTagClassEvt = await podDBC.parseNewTagClassLog(
      newTagClassRcp.logs[0]
    );
    console.log(
      "tagBenchmark newTagClassEvt:",
      JSON.stringify(newTagClassEvt, undefined, 2)
    );

    const tagObject = buildTagObject(await signers[1].getAddress());
    const setTagTx = await podDBC.setTag(
      newTagClassEvt.ClassId,
      tagObject,
      "0x"
    );
    setTagTx.wait();

    const setTagRcp = await hre.ethers.provider.getTransactionReceipt(
      setTagTx.hash
    );

    console.log("setTag gasUsed:", setTagRcp.gasUsed.toNumber());

    const setTagEvt = await podDBC.parseSetTagLog(setTagRcp.logs[0]);
    console.log(
      "tagBenchmark newTagClassEvt:",
      JSON.stringify(setTagEvt, undefined, 2)
    );
  });

  it("nfTagBenchmark", async function () {
    const fieldBuilder = new TagClassFieldBuilder().put(
      "auth",
      TagFieldType.Bool
    );
    const tagClassTx = await podDBC.newTagClass(
      "nfTagBenchmark",
      fieldBuilder.getFieldNames(),
      fieldBuilder.getFieldTypes(),
      "nfTagBenchmark"
    );
    tagClassTx.wait();

    const newTagClassRcp = await hre.ethers.provider.getTransactionReceipt(
      tagClassTx.hash
    );
    console.log("newTagClass gasUsed:", newTagClassRcp.gasUsed.toNumber());
    const newTagClassEvt = await podDBC.parseNewTagClassLog(
      newTagClassRcp.logs[0]
    );
    console.log(
      "nfTagBenchmark newTagClassEvt:",
      JSON.stringify(newTagClassEvt, undefined, 2)
    );

    const tagObject = buildTagObject(await signers[1].getAddress());
    const setTagTx = await podDBC.setTag(
      newTagClassEvt.ClassId,
      tagObject,
      new WriteBuffer().writeBool(true).getBytes()
    );
    setTagTx.wait();

    const setTagRcp = await hre.ethers.provider.getTransactionReceipt(
      setTagTx.hash
    );

    console.log("setTag gasUsed:", setTagRcp.gasUsed.toNumber());

    const setTagEvt = await podDBC.parseSetTagLog(setTagRcp.logs[0]);
    console.log(
      "nfTagBenchmark newTagClassEvt:",
      JSON.stringify(setTagEvt, undefined, 2)
    );
  });
});
