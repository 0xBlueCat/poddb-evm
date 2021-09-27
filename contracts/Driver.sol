// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./Serialization.sol";
import "./IStorage.sol";
import "./librarys/Ownable.sol";
import "./WriteBuffer.sol";
import "./IDriver.sol";
import "./ReadBuffer.sol";

contract Driver is Ownable, IDriver {
    using WriteBuffer for *;
    using ReadBuffer for *;

    IStorage private storageContact;

    constructor(address _storageContact) Ownable() {
        storageContact = IStorage(_storageContact);
    }

    function setTagClass(IPodDB.TagClass calldata tagClass)
        external
        override
        onlyOwner
    {
        bytes memory data = Serialization.serializeTagClass(tagClass);
        storageContact.set(tagClass.ClassId, data);
    }

    function setTagClassInfo(IPodDB.TagClassInfo calldata tagClassInfo)
        external
        override
        onlyOwner
    {
        bytes memory data = Serialization.serializeTagClassInfo(tagClassInfo);
        bytes20 id = genTagClassInfoId(tagClassInfo.ClassId);
        storageContact.set(id, data);
    }

    function setTagClassAll(
        IPodDB.TagClass calldata tagClass,
        IPodDB.TagClassInfo calldata tagClassInfo
    ) external override onlyOwner {
        bytes memory data = Serialization.serializeTagClass(tagClass);
        storageContact.set(tagClass.ClassId, data);

        data = Serialization.serializeTagClassInfo(tagClassInfo);
        bytes20 id = genTagClassInfoId(tagClassInfo.ClassId);
        storageContact.set(id, data);
    }

    function hasTagClass(bytes20 classId)
        external
        view
        override
        returns (bool)
    {
        return storageContact.has(classId);
    }

    function hasTagClassInfo(bytes20 classId)
        external
        view
        override
        returns (bool)
    {
        bytes20 id = genTagClassInfoId(classId);
        return storageContact.has(id);
    }

    function deleteTagClass(bytes20 classId) external override onlyOwner {
        storageContact.del(classId);
    }

    function deleteTagClassInfo(bytes20 classId) external override onlyOwner {
        bytes20 id = genTagClassInfoId(classId);
        storageContact.del(id);
    }

    function getTagClass(bytes20 classId, uint8 version)
        external
        view
        override
        returns (IPodDB.TagClass memory tagClass)
    {
        bytes memory data = storageContact.get(classId);
        tagClass = Serialization.deserializeTagClass(data, version);
        tagClass.ClassId = classId;
        return tagClass;
    }

    function getTagClassInfo(bytes20 tagClassId, uint8 version)
        external
        view
        override
        returns (IPodDB.TagClassInfo memory classInfo)
    {
        bytes20 id = genTagClassInfoId(tagClassId);
        bytes memory data = storageContact.get(id);
        classInfo = Serialization.deserializeTagClassInfo(data, version);
        classInfo.ClassId = tagClassId;
        return classInfo;
    }

    function setTag(IPodDB.Tag calldata tag) external override onlyOwner {
        bytes memory data = Serialization.serializeTag(tag);
        storageContact.set(tag.TagId, data);
    }

    function getTag(bytes20 tagId, uint8 version)
        external
        view
        override
        returns (IPodDB.Tag memory tag)
    {
        bytes memory data = storageContact.get(tagId);
        tag = Serialization.deserializeTag(data, version);
        tag.TagId = tagId;
        return tag;
    }

    function hasTag(bytes20 tagId) external view override returns (bool) {
        return storageContact.has(tagId);
    }

    function deleteTag(bytes20 tagId) external override onlyOwner {
        storageContact.del(tagId);
    }

    function genTagClassInfoId(bytes20 classId)
        internal
        pure
        returns (bytes20)
    {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(21).writeBytes20(classId).writeUint8(uint8(0));
        return bytes20(keccak256(wBuf.getBytes()));
    }
}
