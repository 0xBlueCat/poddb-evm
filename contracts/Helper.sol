// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "./WriteBuffer.sol";
import "./ReadBuffer.sol";
import "./interface/IPodDB.sol";

library Helper {
    using WriteBuffer for *;
    using ReadBuffer for *;

    struct TagClassFieldBuilder {
        WriteBuffer.buffer _nBuf;
        WriteBuffer.buffer _tBuf;
    }

    function init(TagClassFieldBuilder memory builder)
        internal
        pure
        returns (TagClassFieldBuilder memory)
    {
        builder._nBuf.init(64);
        builder._tBuf.init(32);
        return builder;
    }

    function put(
        TagClassFieldBuilder memory builder,
        string memory fieldName,
        IPodDB.TagFieldType fieldType,
        bool isArray
    ) internal pure returns (TagClassFieldBuilder memory) {
        if (builder._nBuf.length() != 0) {
            builder._nBuf.writeString(",");
        }
        builder._nBuf.writeString(fieldName);
        if (isArray) {
            builder._tBuf.writeUint8(uint8(IPodDB.TagFieldType.Array));
        }
        builder._tBuf.writeUint8(uint8(fieldType));
        return builder;
    }

    function getFieldNames(TagClassFieldBuilder memory builder)
        internal
        pure
        returns (string memory)
    {
        return string(builder._nBuf.getBytes());
    }

    function getFieldTypes(TagClassFieldBuilder memory builder)
        internal
        pure
        returns (bytes memory)
    {
        return builder._tBuf.getBytes();
    }
}
