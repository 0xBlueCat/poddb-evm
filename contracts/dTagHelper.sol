// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "./WriteBuffer.sol";
import "./ReadBuffer.sol";
import "./dTagCommon.sol";

library dTagHelper {
    using WriteBuffer for *;
    using ReadBuffer for *;
    using dTagCommon for *;

    function buildFlags(
        bool multiIssue,
        bool canInherit,
        bool isPublic
    ) internal pure returns (uint8) {
        uint8 flags = 0;
        if (multiIssue) {
            flags |= 1;
        }
        if (canInherit) {
            flags |= 2;
        }
        if (isPublic) {
            flags |= 4;
        }
        return flags;
    }

    struct TagSchemaFieldBuilder {
        WriteBuffer.buffer _buf;
        uint256 _count;
    }

    function init(
        TagSchemaFieldBuilder memory builder,
        WriteBuffer.buffer memory buf
    ) internal pure returns (TagSchemaFieldBuilder memory) {
        builder._buf = buf.writeUint8(0);
        builder._count = 0;
        return builder;
    }

    function put(
        TagSchemaFieldBuilder memory builder,
        string memory fieldName,
        dTagCommon.TagFieldType fieldType
    ) internal pure returns (TagSchemaFieldBuilder memory) {
        builder._buf.writeString(fieldName).writeUint8(uint8(fieldType));
        builder._count++;
        return builder;
    }

    function build(TagSchemaFieldBuilder memory builder)
        internal
        pure
        returns (bytes memory)
    {
        return builder._buf.writeVarUintAt(0, builder._count, 1).getBytes();
    }
}
