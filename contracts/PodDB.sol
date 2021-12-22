// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./WriteBuffer.sol";
import "./ReadBuffer.sol";
import "./TagFlags.sol";
import "./TagClassFlags.sol";
import "./Validator.sol";
import "./interfaces/IDriver.sol";
import "./interfaces/IPodDB.sol";
import "./librarys/Ownable.sol";

contract PodDB is Ownable, IPodDB {
    using WriteBuffer for *;
    using ReadBuffer for *;
    using TagFlags for *;
    using TagClassFlags for *;
    using Validator for *;

    IDriver private driver;

    uint256 nonce;
    uint256 public constant Version = 2;

    constructor(address _driver) Ownable() {
        driver = IDriver(_driver);
    }

    function newTagClass(
        string calldata tagName,
        string calldata fieldNames,
        bytes calldata fieldTypes,
        string calldata desc,
        uint8 flags,
        TagAgent calldata agent
    ) external override returns (bytes20) {
        require(bytes(tagName).length > 0, "PODDB: tagName cannot empty");
        Validator.validateTagClassField(fieldNames, fieldTypes);
        require(
            TagClassFlags.flagsValid(flags) &&
                !TagClassFlags.hasDeprecatedFlag(flags),
            "PODDB: invalid tagClass flags"
        );

        TagClass memory tagClass = TagClass(
            genTagClassId(),
            uint8(Version),
            msg.sender,
            fieldTypes,
            flags,
            agent
        );
        TagClassInfo memory classInfo = TagClassInfo(
            tagClass.ClassId,
            tagClass.Version,
            tagName,
            fieldNames,
            desc
        );

        _newTagClass(tagClass, classInfo);
        return tagClass.ClassId;
    }

    function _newTagClass(
        IPodDB.TagClass memory tagClass,
        IPodDB.TagClassInfo memory tagClassInfo
    ) internal {
        _setTagClassAll(tagClass, tagClassInfo);

        emit NewTagClass(
            tagClass.ClassId,
            tagClassInfo.TagName,
            tagClass.Owner,
            tagClassInfo.FieldNames,
            tagClass.FieldTypes,
            tagClassInfo.Desc,
            tagClass.Flags,
            tagClass.Agent
        );
    }

    function getTagClass(bytes20 classId)
        external
        view
        override
        returns (TagClass memory)
    {
        return driver.getTagClass(classId, uint8(Version));
    }

    function getTagClassInfo(bytes20 classId)
        external
        view
        override
        returns (TagClassInfo memory)
    {
        return driver.getTagClassInfo(classId, uint8(Version));
    }

    function getTagById(bytes20 tagId)
        internal
        view
        returns (Tag memory tag, bool valid)
    {
        tag = _getTag(tagId);
        if (tag.Version == 0) {
            return (tag, valid);
        }
        valid = tag.ExpiredAt == 0 || uint32(block.timestamp) <= tag.ExpiredAt;
        return (tag, valid);
    }

    function getTagByObject(bytes20 tagClassId, TagObject calldata object)
        external
        view
        override
        returns (Tag memory tag, bool valid)
    {
        bytes20 tagId = genTagId(tagClassId, object, false);
        (tag, valid) = getTagById(tagId);
        if (valid) {
            tag.ClassId = tagClassId;
            return (tag, valid);
        }
        if (object.Type != ObjectType.NFT) {
            return (tag, valid);
        }

        //check wildcard object
        tagId = genTagId(tagClassId, object, true);
        (tag, valid) = getTagById(tagId);
        if (valid) {
            tag.ClassId = tagClassId;
        }
        return (tag, valid);
    }

    function hasTag(bytes20 tagClassId, TagObject calldata object)
        external
        view
        override
        returns (bool valid)
    {
        (, valid) = this.getTagByObject(tagClassId, object);
        return valid;
    }

    function checkTagAuth(TagClass memory tagClass)
        internal
        view
        returns (bool)
    {
        if (tagClass.Owner == msg.sender) {
            return true;
        }
        //check agent of owner permission
        if (tagClass.Agent.Agent == bytes20(0)) {
            //no agent
            return false;
        }
        if (tagClass.Agent.Type == AgentType.Address) {
            return tagClass.Agent.Agent == bytes20(msg.sender);
        }
        TagObject memory object = TagObject(
            ObjectType.TagClass,
            msg.sender,
            uint256(0)
        );
        return this.hasTag(tagClass.Agent.Agent, object);
    }

    function getTagData(bytes20 tagClassId, TagObject calldata object)
        external
        view
        override
        returns (bytes memory data)
    {
        (Tag memory tag, bool valid) = this.getTagByObject(tagClassId, object);
        if (valid) {
            data = tag.Data;
        }
        return data;
    }

    function updateTagClass(
        bytes20 classId,
        address newOwner,
        TagAgent calldata newAgent,
        uint8 flags
    ) external override {
        TagClass memory tagClass = this.getTagClass(classId);
        require(
            tagClass.Owner == msg.sender,
            "PODDB: only owner can update tagClass"
        );
        require(
            TagClassFlags.flagsValid(flags),
            "PODDB: invalid tagClass flags"
        );

        tagClass.Owner = newOwner;
        tagClass.Agent = newAgent;
        tagClass.Flags = flags;

        driver.setTagClass(tagClass);

        emit UpdateTagClass(classId, newOwner, flags, newAgent);
    }

    function updateTagClassInfo(
        bytes20 classId,
        string calldata tagName,
        string calldata desc
    ) external override {
        TagClass memory tagClass = this.getTagClass(classId);
        require(
            tagClass.Owner == msg.sender,
            "PODDB: only owner can update tagClassInfo"
        );

        TagClassInfo memory classInfo = this.getTagClassInfo(classId);
        classInfo.TagName = tagName;
        classInfo.Desc = desc;
        driver.setTagClassInfo(classInfo);

        emit UpdateTagClassInfo(classId, tagName, desc);
    }

    function setTag(
        bytes20 tagClassId,
        TagObject calldata object,
        bytes calldata data,
        uint32 expiredTime, //Expiration time of tag in seconds, 0 means never expires
        uint8 tagFlags
    ) external override returns (bytes20 tagId) {
        TagClass memory tagClass = this.getTagClass(tagClassId);
        require(tagClass.Owner != address(0), "PODDB: invalid tagClassId");
        require(checkTagAuth(tagClass), "PODDB: invalid tag issuer auth");
        require(
            !TagClassFlags.hasDeprecatedFlag(tagClass.Flags),
            "PODDB: tagClass is deprecated"
        );
        require(TagFlags.flagsValid(tagFlags), "PODDB: invalid tag flags");

        validateTagData(data, tagClass.FieldTypes);

        bool wildcardObject = TagFlags.hasWildcardFlag(tagFlags);
        require(
            !wildcardObject || object.Type == ObjectType.NFT,
            "PODDB: tagObject must be NFT, when has wildcard flag"
        );

        tagId = genTagId(tagClassId, object, wildcardObject);

        Tag memory tag = Tag(
            tagId,
            uint8(Version),
            tagClassId,
            expiredTime == 0 ? 0 : expiredTime + uint32(block.timestamp),
            data
        );

        _setTag(tag);

        emit SetTag(
            tagId,
            object,
            tagClassId,
            data,
            msg.sender,
            tag.ExpiredAt,
            tagFlags
        );
        return tagId;
    }

    function validateTagData(bytes calldata data, bytes memory fieldTypes)
        internal
        pure
    {
        if (fieldTypes.length == 0) {
            return;
        }
        Validator.validateTagData(data, fieldTypes);
    }

    function deleteTag(
        bytes20 tagId,
        bytes20 tagClassId,
        TagObject calldata object
    ) external override returns (bool success) {
        require(
            genTagId(tagClassId, object, false) == tagId ||
                genTagId(tagClassId, object, true) == tagId,
            "PODDB: invalid tagId"
        );
        if (!_hasTag(tagId)) {
            return false;
        }
        TagClass memory tagClass = this.getTagClass(tagClassId);
        require(tagClass.Owner != address(0), "PODDB: invalid tagClassId");
        require(checkTagAuth(tagClass), "PODDB: invalid tag delete auth");

        _deleteTag(tagId);
        emit DeleteTag(tagId);
        return true;
    }

    function genTagClassId() internal returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf
            .init(84)
            .writeAddress(msg.sender)
            .writeBytes32(blockhash(block.number - 1))
            .writeUint256(++nonce);
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function genTagId(
        bytes20 classId,
        TagObject memory object,
        bool wildcardObject
    ) internal pure returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(96).writeBytes20(classId).writeAddress(object.Address);
        if (object.Type == ObjectType.NFT) {
            if (wildcardObject) {
                wBuf.writeUint8(1);
            } else {
                wBuf.writeUint256(object.TokenId);
            }
        }
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function _setTag(Tag memory tag) internal {
        driver.setTag(tag);
    }

    function _setTagClassAll(
        TagClass memory tagClass,
        TagClassInfo memory classInfo
    ) internal {
        driver.setTagClassAll(tagClass, classInfo);
    }

    function _getTag(bytes20 tagId) internal view returns (Tag memory tag) {
        return driver.getTag(tagId, uint8(Version));
    }

    function _hasTag(bytes20 tagId) internal view returns (bool) {
        return driver.hasTag(tagId);
    }

    function _hasTagClass(bytes20 classId) internal view returns (bool) {
        return driver.hasTagClass(classId);
    }

    function _hasTagClassInfo(bytes20 classId) internal view returns (bool) {
        return driver.hasTagClassInfo(classId);
    }

    function _deleteTag(bytes20 tagId) internal {
        driver.deleteTag(tagId);
    }
}
