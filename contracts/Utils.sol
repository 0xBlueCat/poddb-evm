// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "./Common.sol";
import "./WriteBuffer.sol";
import "./ReadBuffer.sol";

library Utils {
    using WriteBuffer for *;
    using ReadBuffer for *;
    using Common for *;

    function serializeAgent(Common.TagAgent memory agent)
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
        returns (Common.TagAgent memory agent)
    {
        if (data.length == 0) {
            return agent;
        }
        ReadBuffer.buffer memory buf = ReadBuffer.fromBytes(data);
        agent.Type = Common.AgentType(buf.readUint8());
        agent.Agent = buf.readBytes20();
        return agent;
    }

    function serializeTagClass(Common.TagClass calldata tagClass)
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

    function deserializeTagClass(bytes calldata data)
        external
        pure
        returns (Common.TagClass memory tagClass)
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

    function serializeTagClassInfo(Common.TagClassInfo calldata classInfo)
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
        returns (Common.TagClassInfo memory classInfo)
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

    function serializeTag(Common.Tag memory tag)
        internal
        pure
        returns (bytes memory)
    {
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

    function deserializeTag(bytes calldata data)
        external
        pure
        returns (Common.Tag memory tag)
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

    function genTagClassId() internal view returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(52).writeAddress(msg.sender).writeUint(block.number);
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function genTagId(
        bytes20 classId,
        Common.TagObject memory object,
        bool multiIssue
    ) internal view returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(128).writeBytes20(classId).writeAddress(object.Address);
        if (object.TokenId != uint256(0)) {
            wBuf.writeUint(object.TokenId);
        }
        if (multiIssue) {
            wBuf.writeUint(block.number);
        }
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function genTagClassInfoId(bytes20 classId)
        internal
        pure
        returns (bytes20)
    {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(21).writeBytes20(classId).writeUint8(uint8(0));
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function getFieldTypes(bytes memory fieldTypes)
        internal
        pure
        returns (Common.TagFieldType[] memory)
    {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(fieldTypes);
        uint256 len = rBuf.readUint8();
        Common.TagFieldType[] memory types = new Common.TagFieldType[](len);
        for (uint256 i = 0; i < len; i++) {
            require(rBuf.skipString() > 0, "field name cannot empty");
            types[i] = Common.TagFieldType(rBuf.readUint8());
        }
        require(rBuf.left() == 0, "invalid fieldTypes");
        return types;
    }

    function validateTagClassFields(bytes calldata fields) external pure {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(fields);
        uint256 len = rBuf.readUint8();
        for (uint256 i = 0; i < len; i++) {
            require(rBuf.skipString() > 0, "field name cannot empty");
            Common.TagFieldType(rBuf.readUint8()); // test whether can convert to TagFieldType
        }
        require(rBuf.left() == 0, "invalid fieldTypes");
    }

    function validateTagData(
        bytes calldata data,
        Common.TagFieldType[] calldata fieldTypes
    ) external pure {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(data);
        for (uint256 i = 0; i < fieldTypes.length; i++) {
            Common.TagFieldType fieldType = fieldTypes[i];
            if (
                fieldType == Common.TagFieldType.String ||
                fieldType == Common.TagFieldType.Bytes
            ) {
                rBuf.skipBytes();
            } else if (
                fieldType == Common.TagFieldType.Uint8 ||
                fieldType == Common.TagFieldType.Bool ||
                fieldType == Common.TagFieldType.Int8 ||
                fieldType == Common.TagFieldType.Bytes1
            ) {
                rBuf.skip(1);
            } else if (
                fieldType == Common.TagFieldType.Uint16 ||
                fieldType == Common.TagFieldType.Int16 ||
                fieldType == Common.TagFieldType.Bytes2
            ) {
                rBuf.skip(2);
            } else if (
                fieldType == Common.TagFieldType.Uint32 ||
                fieldType == Common.TagFieldType.Int32 ||
                fieldType == Common.TagFieldType.Bytes4
            ) {
                rBuf.skip(4);
            } else if (
                fieldType == Common.TagFieldType.Uint64 ||
                fieldType == Common.TagFieldType.Int64 ||
                fieldType == Common.TagFieldType.Bytes8
            ) {
                rBuf.skip(8);
            } else if (
                fieldType == Common.TagFieldType.Address ||
                fieldType == Common.TagFieldType.Bytes20
            ) {
                rBuf.skip(20);
            } else if (
                fieldType == Common.TagFieldType.Uint ||
                fieldType == Common.TagFieldType.Bytes32 ||
                fieldType == Common.TagFieldType.Int
            ) {
                rBuf.skip(32);
            }
        }
        require(rBuf.left() == 0, "invalid tag data");
    }
}
