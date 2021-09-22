// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IStorage {
    //@dev check whether the key exist in storage
    function has(bytes20 key) external view returns (bool);

    //@dev get the value by key
    function get(bytes20 key) external view returns (bytes memory);

    //@dev set the value by key
    function set(bytes20 key, bytes calldata value) external;

    //@dev set the value by key
    function del(bytes20 key) external;
}
