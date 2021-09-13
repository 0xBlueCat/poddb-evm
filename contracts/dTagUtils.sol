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
import "./dTagCommon.sol";
import "./WriteBuffer.sol";
import "./ReadBuffer.sol";

library dTagUtils {
    using WriteBuffer for *;
    using ReadBuffer for *;
    using dTagCommon for *;

    function genTagSchemaId() external view returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(52).writeAddress(msg.sender).writeUint(block.number);
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function genTagId(
        bytes20 schemaId,
        dTagCommon.TagObject memory object,
        bool multiIssue
    ) internal view returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(128).writeBytes20(schemaId).writeAddress(object.Address);
        if (object.TokenId != uint256(0)) {
            wBuf.writeUint(object.TokenId);
        }
        if (multiIssue) {
            wBuf.writeUint(block.number);
        }
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function genTagSchemaInfoId(bytes20 schemaId)
        internal
        pure
        returns (bytes20)
    {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(21).writeBytes20(schemaId).writeUint8(uint8(0));
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function getFieldTypes(bytes memory fieldTypes)
        public
        pure
        returns (dTagCommon.TagFieldType[] memory)
    {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(fieldTypes);
        uint256 len = rBuf.readUint8();
        dTagCommon.TagFieldType[] memory types = new dTagCommon.TagFieldType[](
            len
        );
        for (uint256 i = 0; i < len; i++) {
            require(rBuf.skipString() > 0, "field name cannot empty");
            types[i] = dTagCommon.TagFieldType(rBuf.readUint8());
        }
        require(rBuf.left() == 0, "invalid fieldTypes");
        return types;
    }

    function validateTagData(
        bytes memory data,
        dTagCommon.TagFieldType[] memory fieldTypes
    ) public pure {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(data);
        for (uint256 i = 0; i < fieldTypes.length; i++) {
            dTagCommon.TagFieldType fieldType = fieldTypes[i];
            if (
                fieldType == dTagCommon.TagFieldType.String ||
                fieldType == dTagCommon.TagFieldType.Bytes
            ) {
                rBuf.skipBytes();
            } else if (
                fieldType == dTagCommon.TagFieldType.Bytes1 ||
                fieldType == dTagCommon.TagFieldType.Uint8 ||
                fieldType == dTagCommon.TagFieldType.Int8 ||
                fieldType == dTagCommon.TagFieldType.Bool
            ) {
                rBuf.skip(1);
            } else if (
                fieldType == dTagCommon.TagFieldType.Bytes2 ||
                fieldType == dTagCommon.TagFieldType.Uint16 ||
                fieldType == dTagCommon.TagFieldType.Int16
            ) {
                rBuf.skip(2);
            } else if (
                fieldType == dTagCommon.TagFieldType.Bytes4 ||
                fieldType == dTagCommon.TagFieldType.Uint32 ||
                fieldType == dTagCommon.TagFieldType.Int32
            ) {
                rBuf.skip(4);
            } else if (
                fieldType == dTagCommon.TagFieldType.Bytes8 ||
                fieldType == dTagCommon.TagFieldType.Uint64 ||
                fieldType == dTagCommon.TagFieldType.Int64
            ) {
                rBuf.skip(8);
            } else if (
                fieldType == dTagCommon.TagFieldType.Bytes20 ||
                fieldType == dTagCommon.TagFieldType.Address
            ) {
                rBuf.skip(20);
            } else if (
                fieldType == dTagCommon.TagFieldType.Bytes32 ||
                fieldType == dTagCommon.TagFieldType.Uint ||
                fieldType == dTagCommon.TagFieldType.Int
            ) {
                rBuf.skip(32);
            }
        }
        require(rBuf.left() == 0, "invalid tag data");
    }
}
