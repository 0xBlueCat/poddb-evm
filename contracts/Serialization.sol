// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "./WriteBuffer.sol";
import "./ReadBuffer.sol";
import "./IPodDB.sol";

library Serialization {
    using WriteBuffer for *;
    using ReadBuffer for *;

    function serializeAgent(IPodDB.TagAgent calldata agent)
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
        returns (IPodDB.TagAgent memory agent)
    {
        if (data.length == 0) {
            return agent;
        }
        ReadBuffer.buffer memory buf = ReadBuffer.fromBytes(data);
        agent.Type = IPodDB.AgentType(buf.readUint8());
        agent.Agent = buf.readBytes20();
        return agent;
    }

    function serializeTagClass(IPodDB.TagClass calldata tagClass)
        internal
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

    function deserializeTagClass(bytes memory data, uint256 version)
        internal
        pure
        returns (IPodDB.TagClass memory tagClass)
    {
        if (data.length == 0) {
            return tagClass;
        }
        ReadBuffer.buffer memory buf = ReadBuffer.fromBytes(data);
        tagClass.Version = buf.readUint8();
        require(
            tagClass.Version <= version,
            "DESERIALIZE: incompatible version"
        );

        tagClass.Owner = buf.readAddress();
        tagClass.Fields = buf.readBytes();
        tagClass.Flags = buf.readUint8();
        tagClass.ExpiredTime = buf.readUint32();
        if (buf.readBool()) {
            tagClass.Agent = deserializeAgent(buf.readFixedBytes(21));
        }
        return tagClass;
    }

    function serializeTagClassInfo(IPodDB.TagClassInfo calldata classInfo)
        internal
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

    function deserializeTagClassInfo(bytes memory data, uint256 version)
        internal
        pure
        returns (IPodDB.TagClassInfo memory classInfo)
    {
        if (data.length == 0) {
            return classInfo;
        }
        ReadBuffer.buffer memory buf = ReadBuffer.fromBytes(data);
        classInfo.Version = buf.readUint8();
        require(
            classInfo.Version <= version,
            "DESERIALIZE: incompatible version"
        );

        classInfo.TagName = buf.readString();
        classInfo.Desc = buf.readString();
        classInfo.CreateAt = buf.readUint32();
        return classInfo;
    }

    function serializeTag(IPodDB.Tag calldata tag)
        internal
        pure
        returns (bytes memory)
    {
        WriteBuffer.buffer memory wBuf;
        uint256 count = 25 + tag.Data.length;
        wBuf.init(count);
        wBuf
            .writeUint8(tag.Version)
            .writeBytes20(tag.ClassId)
            .writeBytes(tag.Data)
            .writeUint32(tag.UpdateAt);
        return wBuf.getBytes();
    }

    function deserializeTag(bytes memory data, uint8 version)
        internal
        pure
        returns (IPodDB.Tag memory tag)
    {
        if (data.length == 0) {
            return tag;
        }
        ReadBuffer.buffer memory buf = ReadBuffer.fromBytes(data);
        tag.Version = buf.readUint8();
        require(tag.Version <= version, "DESERIALIZE: incompatible version");

        tag.ClassId = buf.readBytes20();
        tag.Data = buf.readBytes();
        tag.UpdateAt = buf.readUint32();
        return tag;
    }
}
