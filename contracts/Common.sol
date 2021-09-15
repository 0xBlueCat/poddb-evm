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

library Common {
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

    struct TagClass {
        uint8 Version;
        address Owner; // user address or contract address
        bytes Fields; // format Number fieldName_1 fieldType fieldName_2 fieldType fieldName_n fieldType
        // 1:multiIssue flag, means one object have more one tag of this class
        // 2:inherit flag, means when a contract have a tag, all of nft mint by this contact will inherit this tag automatic
        // 4:public flag, means not only the owner of tag class can issuer the tag, other also can issue the tag
        uint8 Flags;
        uint32 ExpiredTime; //expired time(block number) of tag, until tag update, 0 mean tag won't expiration.
        TagAgent Agent;
    }

    struct TagClassInfo {
        uint8 Version;
        string TagName;
        string Desc;
        uint32 CreateAt;
    }

    struct Tag {
        uint8 Version;
        bytes20 ClassId;
        address Issuer;
        bytes Data;
        uint32 UpdateAt;
    }

    enum AgentType {
        Address, // user address or contract address,
        Tag //address which had this tag
    }

    //TagClassAgent can delegate tagClass owner permission to another contract or address which had an special tag
    struct TagAgent {
        AgentType Type; //indicate the of the of agent
        bytes20 Agent; //agent have the same permission with the tagClass owner
    }

    struct TagObject {
        address Address; //EOA address, contract address, even tagClassId
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

    function serializeTagClass(TagClass calldata tagClass)
        external
        pure
        returns (bytes memory)
    {
        WriteBuffer.buffer memory wBuf;
        uint256 count = 50 + tagClass.Fields.length;

        wBuf
            .init(count)
            .writeUint8(tagClass.Version)
            .writeAddress(tagClass.Owner)
            .writeBytes(tagClass.Fields)
            .writeUint8(tagClass.Flags)
            .writeUint32(tagClass.ExpiredTime);

        tagClass.Agent.Agent != bytes20(0)
            ? wBuf.writeBool(true).writeFixedBytes(
                serializeAgent(tagClass.Agent)
            )
            : wBuf.writeBool(false);
        return wBuf.getBytes();
    }

    function deserializeTagClass(bytes memory data)
        internal
        pure
        returns (TagClass memory tagClass)
    {
        if (data.length == 0) {
            return tagClass;
        }
        ReadBuffer.buffer memory buf = ReadBuffer.fromBytes(data);
        tagClass.Version = buf.readUint8();
        tagClass.Owner = buf.readAddress();
        tagClass.Fields = buf.readBytes();
        tagClass.Flags = buf.readUint8();
        tagClass.ExpiredTime = buf.readUint32();
        if (buf.readBool()) {
            tagClass.Agent = deserializeAgent(buf.readFixedBytes(21));
        }
        return tagClass;
    }

    function serializeTagClassInfo(TagClassInfo calldata classInfo)
        external
        pure
        returns (bytes memory)
    {
        WriteBuffer.buffer memory wBuf;
        uint256 count = 9 +
            bytes(classInfo.TagName).length +
            bytes(classInfo.Desc).length;
        wBuf
            .init(count)
            .writeUint8(classInfo.Version)
            .writeString(classInfo.TagName)
            .writeString(classInfo.Desc)
            .writeUint32(classInfo.CreateAt);
        return wBuf.getBytes();
    }

    function deserializeTagClassInfo(bytes calldata data)
        external
        pure
        returns (TagClassInfo memory classInfo)
    {
        if (data.length == 0) {
            return classInfo;
        }
        ReadBuffer.buffer memory buf = ReadBuffer.fromBytes(data);
        classInfo.Version = buf.readUint8();
        classInfo.TagName = buf.readString();
        classInfo.Desc = buf.readString();
        classInfo.CreateAt = buf.readUint32();
        return classInfo;
    }

    function serializeTag(Tag memory tag) internal pure returns (bytes memory) {
        WriteBuffer.buffer memory wBuf;
        uint256 count = 47 + tag.Data.length;
        wBuf.init(count);
        wBuf
            .writeUint8(tag.Version)
            .writeBytes20(tag.ClassId)
            .writeAddress(tag.Issuer)
            .writeBytes(tag.Data)
            .writeUint32(tag.UpdateAt);
        return wBuf.getBytes();
    }

    function deserializeTag(bytes memory data)
        internal
        pure
        returns (Tag memory tag)
    {
        if (data.length == 0) {
            return tag;
        }
        ReadBuffer.buffer memory buf = ReadBuffer.fromBytes(data);
        tag.Version = buf.readUint8();
        tag.ClassId = buf.readBytes20();
        tag.Issuer = buf.readAddress();
        tag.Data = buf.readBytes();
        tag.UpdateAt = buf.readUint32();
        return tag;
    }

    function canMultiIssue(uint8 flag) internal pure returns (bool) {
        return flag & 1 != 0;
    }

    function canInherit(uint8 flag) internal pure returns (bool) {
        return flag & 2 != 0;
    }

    function isPublic(uint8 flag) internal pure returns (bool) {
        return flag & 4 != 0;
    }
}
