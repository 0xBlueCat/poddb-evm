// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./DTag.sol";

abstract contract Storage {
    function has(bytes20 id) external view virtual returns (bool);

    function get(bytes20 id) external view virtual returns (bytes memory);

    function set(bytes20 id, bytes calldata data) external virtual;

    function del(bytes20 id) external virtual;
}

contract PodDB is DTag {
    address private storageContact;

    constructor(address _storageContact) {
        storageContact = _storageContact;
    }

    function has(bytes20 id) external view override returns (bool) {
        Storage db = Storage(storageContact);
        return db.has(id);
    }

    function get(bytes20 id) external view override returns (bytes memory) {
        Storage db = Storage(storageContact);
        return db.get(id);
    }

    function set(bytes20 id, bytes memory data) internal override {
        Storage db = Storage(storageContact);
        db.set(id, data);
    }

    function del(bytes20 id) internal override {
        Storage db = Storage(storageContact);
        db.del(id);
    }
}
