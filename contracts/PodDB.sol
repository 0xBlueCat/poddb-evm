// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./IPodDB.sol";
import "./librarys/Ownable.sol";
import "./IDriver.sol";
import "./WriteBuffer.sol";
import "./ReadBuffer.sol";
import "./TagFlags.sol";
import "./Validator.sol";

contract PodDB is Ownable, IPodDB {
    using WriteBuffer for *;
    using ReadBuffer for *;
    using TagFlags for *;
    using Validator for *;

    IDriver private driver;

    uint256 public constant Version = 1;

    constructor(address _driver) Ownable() {
        driver = IDriver(_driver);
    }

    function newTagClass(
        string calldata tagName,
        bytes calldata fields,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        TagAgent calldata agent
    ) external override returns (bytes20) {
        require(bytes(tagName).length > 0, "PODDB: tagName cannot empty");

        bytes20 classId = genTagClassId();
        require(!_hasTagClass(classId), "PODDB: tagClassId has already exist");

        Validator.validateTagClassFields(fields);

        TagClass memory tagClass = TagClass(
            classId,
            uint8(Version),
            msg.sender,
            fields,
            flags,
            expiredTime,
            agent
        );
        TagClassInfo memory classInfo = TagClassInfo(
            classId,
            uint8(Version),
            tagName,
            desc,
            uint32(block.number)
        );

        _setTagClassAll(tagClass, classInfo);

        emit NewTagClass(
            classId,
            tagName,
            msg.sender,
            fields,
            desc,
            flags,
            expiredTime,
            agent
        );
        return classId;
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
        if (tag.ClassId == bytes20(0)) {
            return (tag, valid);
        }
        TagClass memory tagClass = this.getTagClass(tag.ClassId);
        valid =
            tagClass.ExpiredTime == 0 ||
            (uint64(block.number) - tag.UpdateAt) <= tagClass.ExpiredTime;
        return (tag, valid);
    }

    function getTagByObject(bytes20 tagClassId, TagObject calldata object)
        external
        view
        override
        returns (Tag memory tag, bool valid)
    {
        bytes20 tagId = genTagId(tagClassId, object, false);
        (tag, valid) = this.getTagById(tagId);
        if (valid) {
            return (tag, valid);
        }
        if (object.TokenId == uint256(0)) {
            //non-nft
            return (tag, valid);
        }
        TagClass memory tagClass = this.getTagClass(tagClassId);
        if (!TagFlags.hasInheritFlag(tagClass.Flags)) {
            return (tag, valid);
        }
        //check whether inherit from contact
        TagObject memory contractObj;
        contractObj.Address = object.Address;
        tagId = genTagId(tagClassId, contractObj, false);
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
        uint32 expiredTime,
        TagAgent calldata newAgent
    ) external override {
        TagClass memory tagClass = this.getTagClass(classId);
        require(
            tagClass.Owner == msg.sender,
            "PODDB: only owner can update tagClass"
        );

        tagClass.Owner = newOwner;
        tagClass.Flags = flags;
        tagClass.ExpiredTime = expiredTime;
        tagClass.Agent = newAgent;
        driver.setTagClass(tagClass);

        emit UpdateTagClass(classId, newOwner, flags, expiredTime, newAgent);
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
        bytes calldata data
    ) external override returns (bytes20) {
        TagClass memory tagClass = this.getTagClass(tagClassId);
        require(tagClass.Owner != address(0), "PODDB: invalid tagClassId");
        require(checkTagAuth(tagClass), "PODDB: invalid tag issuer auth");

        TagFieldType[] memory fieldTypes = getFieldTypes(tagClass.Fields);
        Validator.validateTagData(data, fieldTypes);

        bytes20 tagId = genTagId(
            tagClassId,
            object,
            TagFlags.hasMultiIssueFlag(tagClass.Flags)
        );

        Tag memory tag = Tag(
            tagId,
            uint8(Version),
            tagClassId,
            data,
            uint32(block.number)
        );

        _setTag(tag);

        emit SetTag(tagId, object, tagClassId, data);
        return tagId;
    }

    function setTagBatch(
        bytes20 tagClassId,
        TagObject[] calldata objects,
        bytes[] calldata datas
    ) external override returns (bytes20[] memory) {
        require(
            objects.length == datas.length,
            "PODDB: objects length not equal with datas"
        );

        TagClass memory tagClass = this.getTagClass(tagClassId);
        require(tagClass.Owner != address(0), "PODDB: invalid tagClassId");
        require(checkTagAuth(tagClass), "PODDB: invalid tagClass issuer auth");

        TagFieldType[] memory fieldTypes = getFieldTypes(tagClass.Fields);
        bool canMultiIssue = TagFlags.hasMultiIssueFlag(tagClass.Flags);

        bytes20[] memory tagIds = new bytes20[](objects.length);
        for (uint256 i = 0; i < objects.length; i++) {
            bytes20 tagId = genTagId(tagClassId, objects[i], canMultiIssue);
            _newTagBatch(tagClassId, tagId, fieldTypes, objects[i], datas[i]);
            tagIds[i] = tagId;
        }
        return tagIds;
    }

    function _newTagBatch(
        bytes20 classId,
        bytes20 tagId,
        TagFieldType[] memory fieldTypes,
        TagObject calldata object,
        bytes calldata data
    ) internal {
        Validator.validateTagData(data, fieldTypes);

        Tag memory tag = Tag(
            tagId,
            uint8(Version),
            classId,
            data,
            uint32(block.number)
        );
        _setTag(tag);

        emit SetTag(tagId, object, classId, data);
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

    function genTagClassId() internal view returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(52).writeAddress(msg.sender).writeUint(block.number);
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function genTagId(
        bytes20 classId,
        TagObject memory object,
        bool multiIssue
    ) internal view returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(128).writeBytes20(classId).writeAddress(object.Address);
        if (object.TokenId != uint256(0)) {
            wBuf.writeUint(object.TokenId);
        }
        if (multiIssue) {
            wBuf.writeUint(block.number);
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

    function getFieldTypes(bytes memory fieldTypes)
        internal
        pure
        returns (TagFieldType[] memory)
    {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(fieldTypes);
        uint256 len = rBuf.readUint8();
        TagFieldType[] memory types = new TagFieldType[](len);
        for (uint256 i = 0; i < len; i++) {
            require(rBuf.skipString() > 0, "field name cannot empty");
            types[i] = TagFieldType(rBuf.readUint8());
        }
        require(rBuf.left() == 0, "invalid fieldTypes");
        return types;
    }
}
