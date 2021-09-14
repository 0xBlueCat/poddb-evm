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
import "./Common.sol";
import "./WriteBuffer.sol";
import "./ReadBuffer.sol";

library Utils {
    using WriteBuffer for *;
    using ReadBuffer for *;
    using Common for *;

    function genTagClassId() external view returns (bytes20 id) {
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
        public
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

    function validateTagClassFields(bytes calldata fields) public pure {
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
        Common.TagFieldType[] memory fieldTypes
    ) public pure {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(data);
        for (uint256 i = 0; i < fieldTypes.length; i++) {
            Common.TagFieldType fieldType = fieldTypes[i];
            if (
                fieldType == Common.TagFieldType.String ||
                fieldType == Common.TagFieldType.Bytes
            ) {
                rBuf.skipBytes();
            } else if (
                fieldType == Common.TagFieldType.Bytes1 ||
                fieldType == Common.TagFieldType.Uint8 ||
                fieldType == Common.TagFieldType.Int8 ||
                fieldType == Common.TagFieldType.Bool
            ) {
                rBuf.skip(1);
            } else if (
                fieldType == Common.TagFieldType.Bytes2 ||
                fieldType == Common.TagFieldType.Uint16 ||
                fieldType == Common.TagFieldType.Int16
            ) {
                rBuf.skip(2);
            } else if (
                fieldType == Common.TagFieldType.Bytes4 ||
                fieldType == Common.TagFieldType.Uint32 ||
                fieldType == Common.TagFieldType.Int32
            ) {
                rBuf.skip(4);
            } else if (
                fieldType == Common.TagFieldType.Bytes8 ||
                fieldType == Common.TagFieldType.Uint64 ||
                fieldType == Common.TagFieldType.Int64
            ) {
                rBuf.skip(8);
            } else if (
                fieldType == Common.TagFieldType.Bytes20 ||
                fieldType == Common.TagFieldType.Address
            ) {
                rBuf.skip(20);
            } else if (
                fieldType == Common.TagFieldType.Bytes32 ||
                fieldType == Common.TagFieldType.Uint ||
                fieldType == Common.TagFieldType.Int
            ) {
                rBuf.skip(32);
            }
        }
        require(rBuf.left() == 0, "invalid tag data");
    }
}
