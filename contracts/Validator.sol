// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "./ReadBuffer.sol";
import "./IPodDB.sol";

library Validator {
    using ReadBuffer for *;

    function validateTagClassFields(bytes calldata fields) internal pure {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(fields);
        uint256 len = rBuf.readUint8();
        for (uint256 i = 0; i < len; i++) {
            require(
                rBuf.skipString() > 0,
                "VALIDATOR: field name cannot empty"
            );
            IPodDB.TagFieldType(rBuf.readUint8()); // test whether can convert to TagFieldType
        }
        require(rBuf.left() == 0, "VALIDATOR: invalid fieldTypes");
    }

    function validateTagData(
        bytes calldata data,
        IPodDB.TagFieldType[] calldata fieldTypes
    ) external pure {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(data);
        for (uint256 i = 0; i < fieldTypes.length; i++) {
            IPodDB.TagFieldType fieldType = fieldTypes[i];
            if (
                fieldType == IPodDB.TagFieldType.String ||
                fieldType == IPodDB.TagFieldType.Bytes
            ) {
                rBuf.skipBytes();
            } else if (
                fieldType == IPodDB.TagFieldType.Uint8 ||
                fieldType == IPodDB.TagFieldType.Bool ||
                fieldType == IPodDB.TagFieldType.Int8 ||
                fieldType == IPodDB.TagFieldType.Bytes1
            ) {
                rBuf.skip(1);
            } else if (
                fieldType == IPodDB.TagFieldType.Uint16 ||
                fieldType == IPodDB.TagFieldType.Int16 ||
                fieldType == IPodDB.TagFieldType.Bytes2
            ) {
                rBuf.skip(2);
            } else if (
                fieldType == IPodDB.TagFieldType.Uint32 ||
                fieldType == IPodDB.TagFieldType.Int32 ||
                fieldType == IPodDB.TagFieldType.Bytes4
            ) {
                rBuf.skip(4);
            } else if (
                fieldType == IPodDB.TagFieldType.Uint64 ||
                fieldType == IPodDB.TagFieldType.Int64 ||
                fieldType == IPodDB.TagFieldType.Bytes8
            ) {
                rBuf.skip(8);
            } else if (
                fieldType == IPodDB.TagFieldType.Address ||
                fieldType == IPodDB.TagFieldType.Bytes20
            ) {
                rBuf.skip(20);
            } else if (
                fieldType == IPodDB.TagFieldType.Uint ||
                fieldType == IPodDB.TagFieldType.Bytes32 ||
                fieldType == IPodDB.TagFieldType.Int
            ) {
                rBuf.skip(32);
            }
        }
        require(rBuf.left() == 0, "VALIDATOR: invalid tag data");
    }
}
