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
        require(TagClassFlags.flagsValid(flags), "PODDB: invalid tagClass flags");

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
        external
        view
        override
        returns (Tag memory tag, bool valid)
    {
        tag = _getTag(tagId);
        if(tag.ClassId == bytes20(0)){
            return (tag, valid);
        }
        valid = tag.ExpiredAt == 0 || uint32(block.timestamp)  <= tag.ExpiredAt;
        return (tag, valid);
    }

    function getTagByObject(bytes20 tagClassId, TagObject calldata object)
        external
        view
        override
        returns (Tag memory tag, bool valid)
    {
        bytes20 tagId = genTagId(tagClassId, object, false, false);
        (tag, valid) = this.getTagById(tagId);
        if (valid) {
            return (tag, valid);
        }
        if (object.TokenId == uint256(0)) {
            //non-nft
            return (tag, valid);
        }

        //check wildcard object
        TagObject memory contractObj;
        contractObj.Address = object.Address;
        tagId = genTagId(tagClassId, contractObj, false, true);
        return this.getTagById(tagId);
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
        TagObject memory object = TagObject(msg.sender, uint256(0));
        return this.hasTag(tagClass.Agent.Agent, object);
    }

    function updateTagClass(
        bytes20 classId,
        address newOwner,
        uint8 flags,
        TagAgent calldata newAgent
    ) external override {
        TagClass memory tagClass = this.getTagClass(classId);
        require(
            tagClass.Owner == msg.sender,
            "PODDB: only owner can update tagClass"
        );
        require(TagClassFlags.flagsValid(flags), "PODDB: invalid tagClass flags");

        tagClass.Owner = newOwner;
        tagClass.Flags = flags;
        tagClass.Agent = newAgent;
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
        uint8 flags
    ) external override returns (bytes20) {
        TagClass memory tagClass = this.getTagClass(tagClassId);
        require(tagClass.Owner != address(0), "PODDB: invalid tagClassId");
        require(checkTagAuth(tagClass), "PODDB: invalid tag issuer auth");
        require(TagFlags.flagsValid(flags), "PODDB: invalid tag flags");

        validateTagData(data, tagClass.FieldTypes);

        bool multiTag = TagClassFlags.hasMultiIssueFlag(tagClass.Flags);
        bool wildcardObject = TagFlags.hasWildcardFlag(flags);
        require(wildcardObject && object.TokenId == 0, "PODDB: tokenId should be zero, when has wildcard flag");

        bytes20 tagId = genTagId(tagClassId, object, multiTag, wildcardObject);

        if (!multiTag) {
            Tag memory tag = Tag(
                tagId,
                uint8(Version),
                tagClassId,
                expiredTime == 0? 0 : expiredTime + uint32(block.timestamp),
                data
            );

            _setTag(tag);
        }

        emit SetTag(tagId, object, tagClassId, data, msg.sender, flags);
        return tagId;
    }

    function validateTagData(bytes calldata data, bytes memory fieldTypes) internal pure {
        if(fieldTypes.length == 0){
            return;
        }
        Validator.validateTagData(data, fieldTypes);
    }

    function deleteTag(bytes20 tagId) external override {
        Tag memory tag = _getTag(tagId);
        require(tag.ClassId != bytes20(0), "PODDB: invalid tagId");

        TagClass memory tagClass = this.getTagClass(tag.ClassId);
        require(tagClass.Owner != address(0), "PODDB: invalid classId of tag");
        require(checkTagAuth(tagClass), "PODDB: invalid tag delete auth");

        _deleteTag(tagId);

        emit DeleteTag(tagId);
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
        bool multiIssue,
        bool wildcardObject
    ) internal view returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(128).writeBytes20(classId).writeAddress(object.Address);
        if (object.TokenId != uint256(0)) {
            wBuf.writeUint256(object.TokenId);
        }
        if (multiIssue) {
            wBuf.writeUint256(block.number);
        }
        if(wildcardObject) {
            wBuf.writeUint16(1);
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
