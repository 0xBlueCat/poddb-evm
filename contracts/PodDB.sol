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

    function checkTagClassUpdateAuth(TagClass memory tagClass)
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

    function checkTagIssuerAuth(TagClass memory tagClass)
        internal
        view
        returns (bool)
    {
        if (TagFlags.hasPublicFlag(tagClass.Flags)) {
            return true;
        }
        return checkTagClassUpdateAuth(tagClass);
    }

    function checkTagUpdateAuth(TagClass memory tagClass, address tagIssuer)
        internal
        view
        returns (bool)
    {
        if (TagFlags.hasPublicFlag(tagClass.Flags)) {
            return tagIssuer == msg.sender;
        }
        return checkTagClassUpdateAuth(tagClass);
    }

    function updateTagClass(
        bytes20 classId,
        string calldata tagName,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        TagAgent calldata agent
    ) external override {
        TagClass memory tagClass = this.getTagClass(classId);
        require(tagClass.Owner != address(0), "PODDB: invalid tagClassId");

        if (agent.Agent != bytes20(0)) {
            require(
                tagClass.Owner == msg.sender,
                "PODDB: only owner can update tag class agent"
            );
        } else {
            require(
                checkTagClassUpdateAuth(tagClass),
                "PODDB: invalid tag class update auth"
            );
        }

        tagClass.Flags = flags;
        tagClass.Agent = agent;
        tagClass.ExpiredTime = expiredTime;

        TagClassInfo memory classInfo = this.getTagClassInfo(classId);
        classInfo.TagName = tagName;
        classInfo.Desc = desc;

        _setTagClassAll(tagClass, classInfo);

        emit UpdateTagClass(classId, tagName, desc, flags, agent);
    }

    function newTag(
        bytes20 tagClassId,
        TagObject calldata object,
        bytes calldata data
    ) external override returns (bytes20) {
        TagClass memory tagClass = this.getTagClass(tagClassId);
        require(tagClass.Owner != address(0), "PODDB: invalid tagClassId");

        require(
            checkTagIssuerAuth(tagClass),
            "PODDB: invalid tagClass issuer auth"
        );

        TagFieldType[] memory fieldTypes = getFieldTypes(tagClass.Fields);
        Validator.validateTagData(data, fieldTypes);

        bytes20 tagId = genTagId(
            tagClassId,
            object,
            TagFlags.hasMultiIssueFlag(tagClass.Flags)
        );

        require(!_hasTag(tagId), "PODDB: tagId has already exist");

        Tag memory tag = Tag(
            tagId,
            uint8(Version),
            tagClassId,
            msg.sender,
            data,
            uint32(block.number)
        );

        _setTag(tag);

        emit NewTag(object, tagClassId, tagId, msg.sender, data);
        return tagId;
    }

    function newTagBatch(
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
        require(
            checkTagIssuerAuth(tagClass),
            "PODDB: invalid tagClass issuer auth"
        );

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
        require(!_hasTag(tagId), "PODDB: tagId has already exist");

        Validator.validateTagData(data, fieldTypes);

        Tag memory tag = Tag(
            tagId,
            uint8(Version),
            classId,
            msg.sender,
            data,
            uint32(block.number)
        );
        _setTag(tag);

        emit NewTag(object, classId, tagId, msg.sender, data);
    }

    function updateTag(bytes20 tagId, bytes calldata data) external override {
        Tag memory tag = _getTag(tagId);
        require(tag.ClassId != bytes20(0), "PODDB: invalid tagId");

        TagClass memory tagClass = this.getTagClass(tag.ClassId);
        require(
            tagClass.Owner != address(0),
            "PODDB: invalid tagClassId of tag"
        );
        require(
            checkTagUpdateAuth(tagClass, tag.Issuer),
            "PODDB: invalid tag update auth"
        );

        TagFieldType[] memory fieldTypes = getFieldTypes(tagClass.Fields);
        Validator.validateTagData(data, fieldTypes);

        tag.Data = data;
        tag.UpdateAt = uint32(block.number);

        _setTag(tag);

        emit UpdateTag(tagId, data);
    }

    function deleteTag(bytes20 tagId) external override {
        Tag memory tag = _getTag(tagId);
        require(tag.ClassId != bytes20(0), "PODDB: invalid tagId");

        TagClass memory tagClass = this.getTagClass(tag.ClassId);
        require(tagClass.Owner != address(0), "PODDB: invalid classId of tag");
        require(
            checkTagUpdateAuth(tagClass, tag.Issuer),
            "PODDB: invalid tag delete auth"
        );

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
        IPodDB.TagObject memory object,
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
