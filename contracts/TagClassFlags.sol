// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "./interfaces/IPodDB.sol";

library TagClassFlags {
    function buildFlags(bool multiIssue, bool deprecated)
        internal
        pure
        returns (uint8)
    {
        uint8 flags = 0;
        if (multiIssue) {
            flags |= 1;
        }
        if (deprecated) {
            flags |= 128;
        }
        return flags;
    }

    function hasMultiIssueFlag(uint8 flag) internal pure returns (bool) {
        return flag & 1 != 0;
    }

    function hasDeprecatedFlag(uint8 flag) internal pure returns (bool) {
        return flag & 128 != 0;
    }

    function flagsValid(uint8 flag) internal pure returns (bool) {
        return flag == 0 || flag == 1;
    }
}
