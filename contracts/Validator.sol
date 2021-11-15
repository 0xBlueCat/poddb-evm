// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "./ReadBuffer.sol";
import "./Strings.sol";
import "./interfaces/IPodDB.sol";

library Validator {
    using ReadBuffer for *;
    using Strings for *;

    function validateTagClassField(
        string calldata fieldNames,
        bytes calldata fieldTypes
    ) external pure {
        if(fieldTypes.length == 0 && bytes(fieldNames).length == 0){
            return;
        }
        Strings.slice memory fNames = fieldNames.toSlice();
        Strings.slice memory delim = ",".toSlice();
        Strings.slice memory field;
        uint256 nameNum = fNames.count(delim) + 1;
        for (uint256 i = 0; i < nameNum; i++) {
            field = fNames.split(delim);
            require(field._len > 0, "VALIDATOR: field name cannot empty");
        }

        uint256 typeNum = 0;
        for (uint256 i = 0; i < fieldTypes.length; i++) {
            IPodDB.TagFieldType ty = IPodDB.TagFieldType(uint8(fieldTypes[i]));
            if (ty == IPodDB.TagFieldType.Array) {
                continue;
            }
            typeNum++;
        }
        require(
            typeNum == nameNum,
            "VALIDATOR: num of field name not equal num of field type"
        );
    }

    function validateTagData(bytes calldata data, bytes memory fieldTypes)
        external
        pure
    {
        ReadBuffer.buffer memory dataBuf = ReadBuffer.fromBytes(data);
        bool isArray = false;
        for (uint256 i; i < fieldTypes.length; i++) {
            IPodDB.TagFieldType fieldType = IPodDB.TagFieldType(
                uint8(fieldTypes[i])
            );
            if (fieldType == IPodDB.TagFieldType.Array) {
                isArray = true;
                continue;
            }
            if (!isArray) {
                validateBaseType(fieldType, dataBuf);
                continue;
            }
            //note that array type doest not support nested array!
            validateArrayType(fieldType, dataBuf);
            isArray = false;
        }
        require(dataBuf.left() == 0, "VALIDATOR: invalid tag data");
    }

    function validateArrayType(
        IPodDB.TagFieldType elemType,
        ReadBuffer.buffer memory dataBuf
    ) internal pure {
        uint256 num = dataBuf.readUint16(); // number of array element
        for (uint256 i = 0; i < num; i++) {
            validateBaseType(elemType, dataBuf);
        }
    }

    function validateBaseType(
        IPodDB.TagFieldType fieldType,
        ReadBuffer.buffer memory rBuf
    ) internal pure {
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
        } else if (fieldType == IPodDB.TagFieldType.Bytes3) {
            rBuf.skip(3);
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
            fieldType == IPodDB.TagFieldType.Uint256 ||
            fieldType == IPodDB.TagFieldType.Bytes32 ||
            fieldType == IPodDB.TagFieldType.Int256
        ) {
            rBuf.skip(32);
        }
    }
}
