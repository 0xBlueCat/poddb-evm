// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract Owner {
    address private owner;

    event SetOwner(address oldOwner, address newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Owner: caller is not the owner");
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
}
