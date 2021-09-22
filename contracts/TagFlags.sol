// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "./IPodDB.sol";

library TagFlags {
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

    function hasMultiIssueFlag(uint8 flag) internal pure returns (bool) {
        return flag & 1 != 0;
    }

    function hasInheritFlag(uint8 flag) internal pure returns (bool) {
        return flag & 2 != 0;
    }

    function hasPublicFlag(uint8 flag) internal pure returns (bool) {
        return flag & 4 != 0;
    }
}
