// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract Storage {
    address private owner;
    mapping(address => bool) private accessors; // accessor contact address
    mapping(bytes20 => bytes) private db;

    event SetOwner(address oldOwner, address newOwner);
    event AddAccessor(address accessor);
    event DeleteAccessor(address accessor);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyAccessor() {
        require(accessors[msg.sender], "invalid accessor");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit SetOwner(address(0), owner);
    }

    function changeOwner(address newOwner) external onlyOwner {
        emit SetOwner(owner, newOwner);
        owner = newOwner;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function addAccessor(address accessor) external onlyOwner {
        accessors[accessor] = true;
        emit AddAccessor(accessor);
    }

    function deleteAccessor(address accessor) external onlyOwner {
        delete accessors[accessor];
        emit DeleteAccessor(accessor);
    }

    function isAccessor(address accessor) external view returns (bool) {
        return accessors[accessor];
    }

    function has(bytes20 id) external view returns (bool){
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
