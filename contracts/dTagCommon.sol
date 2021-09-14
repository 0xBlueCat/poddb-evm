// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

/**
 * @dev A library for working with mutable byte buffers in Solidity.
 *
 * Byte buffers are mutable and expandable, and provide a variety of primitives
 * for writing to them. At any time you can fetch a bytes object containing the
 * current contents of the buffer. The bytes object should not be stored between
 * operations, as it may change due to resizing of the buffer.
 */

import "./WriteBuffer.sol";
import "./ReadBuffer.sol";

library dTagCommon {
    using WriteBuffer for *;
    using ReadBuffer for *;

    enum TagFieldType {
        Bool,
        Uint,
        Uint8,
        Uint16,
        Uint32,
        Uint64,
        Int,
        Int8,
        Int16,
        Int32,
        Int64,
        Bytes1,
        Bytes2,
        Bytes3,
        Bytes4,
        Bytes8,
        Bytes20,
        Bytes32,
        Address,
        Bytes,
        String
    }

    struct TagSchema {
        uint8 Version;
        address Owner; // user address or contract address
        bytes Fields; // format Number fieldName_1 fieldType fieldName_2 fieldType fieldName_n fieldType
        // 1:multiIssue flag, means one object have more one tag of this schema
        // 2:inherit flag, means when a contract have a tag, all of nft mint by this contact will inherit this tag automatic
        // 4:public flag, means not only the owner of tag schema can issuer the tag, other also can issue the tag
        uint8 Flags;
        uint32 ExpiredTime; //expired time(block number) of tag, until tag update, 0 mean tag won't expiration.
        TagAgent Agent;
    }

    struct TagSchemaInfo {
        uint8 Version;
        string TagName;
        string Desc;
        uint32 CreateAt;
    }

    struct Tag {
        uint8 Version;
        bytes20 SchemaId;
        address Issuer;
        bytes Data;
        uint32 UpdateAt;
    }

    enum AgentType {
        Address, // user address or contract address,
        Tag //address which had this tag
    }

    //TagSchemaAgent can delegate tagSchema owner permission to another contract or address which had an special tag
    struct TagAgent {
        AgentType Type; //indicate the of delegator
        bytes20 Agent; //agent have the same permission with the tagSchema owner
    }

    struct TagObject {
        address Address; //EOA address, contract address, even tagSchemaId
        uint256 TokenId; //NFT tokenId
    }

    function serializeAgent(TagAgent memory agent)
        internal
        pure
        returns (bytes memory)
    {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(21).writeUint8(uint8(agent.Type)).writeBytes20(agent.Agent);
        return wBuf.getBytes();
    }

    function deserializeAgent(bytes memory data)
        internal
        pure
        returns (TagAgent memory agent)
    {
        if (data.length == 0) {
            return agent;
        }
        ReadBuffer.buffer memory buf = ReadBuffer.fromBytes(data);
        agent.Type = AgentType(buf.readUint8());
        agent.Agent = buf.readBytes20();
        return agent;
    }

    function serializeTagSchema(TagSchema memory schema)
        external
        pure
        returns (bytes memory)
    {
        WriteBuffer.buffer memory wBuf;
        uint256 count = 50 + schema.Fields.length;

        wBuf
            .init(count)
            .writeUint8(schema.Version)
            .writeAddress(schema.Owner)
            .writeBytes(schema.Fields)
            .writeUint8(schema.Flags)
            .writeUint32(schema.ExpiredTime);
        schema.Agent.Agent != bytes20(0)
            ? wBuf.writeBool(true).writeFixedBytes(serializeAgent(schema.Agent))
            : wBuf.writeBool(false);
        return wBuf.getBytes();
    }

    function deserializeTagSchema(bytes memory data)
        external
        pure
        returns (TagSchema memory schema)
    {
        if (data.length == 0) {
            return schema;
        }
        ReadBuffer.buffer memory buf = ReadBuffer.fromBytes(data);
        schema.Version = buf.readUint8();
        schema.Owner = buf.readAddress();
        schema.Fields = buf.readBytes();
        schema.Flags = buf.readUint8();
        schema.ExpiredTime = buf.readUint32();
        if (buf.readBool()) {
            schema.Agent = deserializeAgent(buf.readFixedBytes(21));
        }
        return schema;
    }

    function serializeTagSchemaInfo(TagSchemaInfo memory schemaInfo)
        external
        pure
        returns (bytes memory)
    {
        WriteBuffer.buffer memory wBuf;
        uint256 count = 9 +
            bytes(schemaInfo.TagName).length +
            bytes(schemaInfo.Desc).length;
        wBuf
            .init(count)
            .writeUint8(schemaInfo.Version)
            .writeString(schemaInfo.TagName)
            .writeString(schemaInfo.Desc)
            .writeUint32(schemaInfo.CreateAt);
        return wBuf.getBytes();
    }

    function deserializeTagSchemaInfo(bytes memory data)
        external
        pure
        returns (TagSchemaInfo memory schemaInfo)
    {
        if (data.length == 0) {
            return schemaInfo;
        }
        ReadBuffer.buffer memory buf = ReadBuffer.fromBytes(data);
        schemaInfo.Version = buf.readUint8();
        schemaInfo.TagName = buf.readString();
        schemaInfo.Desc = buf.readString();
        schemaInfo.CreateAt = buf.readUint32();
        return schemaInfo;
    }

    function serializeTag(Tag memory tag) external pure returns (bytes memory) {
        WriteBuffer.buffer memory wBuf;
        uint256 count = 47 + tag.Data.length;
        wBuf.init(count);
        wBuf
            .writeUint8(tag.Version)
            .writeBytes20(tag.SchemaId)
            .writeAddress(tag.Issuer)
            .writeBytes(tag.Data)
            .writeUint32(tag.UpdateAt);
        return wBuf.getBytes();
    }

    function deserializeTag(bytes memory data)
        external
        pure
        returns (Tag memory tag)
    {
        if (data.length == 0) {
            return tag;
        }
        ReadBuffer.buffer memory buf = ReadBuffer.fromBytes(data);
        tag.Version = buf.readUint8();
        tag.SchemaId = buf.readBytes20();
        tag.Issuer = buf.readAddress();
        tag.Data = buf.readBytes();
        tag.UpdateAt = buf.readUint32();
        return tag;
    }

    function canMultiIssue(uint8 flag) external pure returns (bool) {
        return flag & 1 != 0;
    }

    function canInherit(uint8 flag) external pure returns (bool) {
        return flag & 2 != 0;
    }

    function isPublic(uint8 flag) external pure returns (bool) {
        return flag & 4 != 0;
    }
}
