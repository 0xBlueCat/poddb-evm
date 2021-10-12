// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "./interfaces/IPodDB.sol";

library TagFlags {
    function buildFlags(bool multiIssue, bool canInherit)
        internal
        pure
        returns (uint8)
    {
        uint8 flags = 0;
        if (multiIssue) {
            flags |= 1;
        }
        if (canInherit) {
            flags |= 2;
        }
        return flags;
    }

    function hasMultiIssueFlag(uint8 flag) internal pure returns (bool) {
        return flag & 1 != 0;
    }

    function hasInheritFlag(uint8 flag) internal pure returns (bool) {
        return flag & 2 != 0;
    }
}
