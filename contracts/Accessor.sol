// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./librarys/Ownable.sol";

contract Accessor is Ownable {
    mapping(address => bool) private accessors; // accessor contact address

    event AddAccessor(address accessor);
    event DeleteAccessor(address accessor);

    modifier onlyAccessor() {
        require(accessors[msg.sender], "ACCESSOR: invalid accessor");
        _;
    }

    constructor() Ownable() {}

    function addAccessor(address accessor) external onlyOwner {
        require(
            accessor != address(0),
            "ACCESSOR: new accessor is the zero address"
        );
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
}
