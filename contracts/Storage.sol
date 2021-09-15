// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./Accessor.sol";

contract Storage is Accessor{
    mapping(bytes20 => bytes) private db;

    function has(bytes20 id) external view returns (bool) {
        return db[id].length > 0;
    }

    function get(bytes20 id) external view returns (bytes memory) {
        return db[id];
    }

    function set(bytes20 id, bytes calldata data) external onlyAccessor {
        db[id] = data;
    }

    function del(bytes20 id) external onlyAccessor {
        delete db[id];
    }
}
