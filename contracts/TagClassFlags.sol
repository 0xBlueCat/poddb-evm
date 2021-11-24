// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "./interfaces/IPodDB.sol";

library TagClassFlags {
    function buildFlags(bool deprecated) internal pure returns (uint8) {
        uint8 flags = 0;
        if (deprecated) {
            flags |= 128;
        }
        return flags;
    }

    function hasDeprecatedFlag(uint8 flag) internal pure returns (bool) {
        return flag & 128 != 0;
    }

    function flagsValid(uint8 flag) internal pure returns (bool) {
        return flag == 0 || flag == 128;
    }
}
