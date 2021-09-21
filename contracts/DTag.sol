// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./WriteBuffer.sol";
import "./ReadBuffer.sol";
import "./Common.sol";
import "./Utils.sol";
import "./DTagClass.sol";

interface IStorage {
    function has(bytes20 id) external view returns (bool);

    function get(bytes20 id) external view returns (bytes memory);

    function set(bytes20 id, bytes calldata data) external;

    function del(bytes20 id) external;
}

contract DTag is DTagClass {
    using WriteBuffer for WriteBuffer.buffer;
    using ReadBuffer for ReadBuffer.buffer;
    using Common for *;
    using Utils for *;

    address private storageContact;

    constructor(address _storageContact) DTagClass() {
        storageContact = _storageContact;
    }

    function has(bytes20 id) external view override returns (bool) {
        IStorage db = IStorage(storageContact);
        return db.has(id);
    }

    function get(bytes20 id) external view override returns (bytes memory) {
        IStorage db = IStorage(storageContact);
        return db.get(id);
    }

    function set(bytes20 id, bytes memory data) internal override {
        IStorage db = IStorage(storageContact);
        db.set(id, data);
    }

    function del(bytes20 id) internal override {
        IStorage db = IStorage(storageContact);
        db.del(id);
    }

    function checkTagClassUpdateAuth(
        address sender,
        Common.TagClass memory tagClass
    ) internal view override returns (bool) {
        if (tagClass.Owner == sender) {
            return true;
        }
        //check agent of owner permission
        if (tagClass.Agent.Agent == bytes20(0)) {
            //no agent
            return false;
        }
        if (tagClass.Agent.Type == Common.AgentType.Address) {
            return tagClass.Agent.Agent == bytes20(sender);
        }
        Common.TagObject memory object = Common.TagObject(sender, uint256(0));
        return this.hasTag(tagClass.Agent.Agent, object);
    }

    function checkTagIssuerAuth(address sender, Common.TagClass memory tagClass)
        internal
        view
        returns (bool)
    {
        if (Utils.isPublic(tagClass.Flags)) {
            return true;
        }
        return checkTagClassUpdateAuth(sender, tagClass);
    }

    function checkTagUpdateAuth(
        address sender,
        Common.TagClass memory tagClass,
        address tagIssuer
    ) internal view returns (bool) {
        if (Utils.isPublic(tagClass.Flags)) {
            return tagIssuer == sender;
        }
        return checkTagClassUpdateAuth(sender, tagClass);
    }

    function newTag(
        address sender,
        bytes20 tagClassId,
        Common.TagObject calldata object,
        bytes calldata data
    ) external onlyOwner returns (bytes20) {
        Common.TagClass memory tagClass = this.getTagClass(tagClassId);
        require(tagClass.Owner != address(0), "DTAG: invalid tagClassId");

        require(
            checkTagIssuerAuth(sender, tagClass),
            "DTAG: invalid tagClass issuer auth"
        );

        Common.TagFieldType[] memory fieldTypes = Utils.getFieldTypes(
            tagClass.Fields
        );
        Utils.validateTagData(data, fieldTypes);

        bytes20 tagId = Utils.genTagId(
            tagClassId,
            object,
            Utils.canMultiIssue(tagClass.Flags)
        );

        require(!this.has(tagId), "DTAG: tagId has already exist");

        Common.Tag memory tag = Common.Tag(
            uint8(Version),
            tagClassId,
            sender,
            data,
            uint32(block.number)
        );

        _setTag(tagId, tag);
        return tagId;
    }

    function newTagBatch(
        address sender,
        bytes20 tagClassId,
        Common.TagObject[] calldata objects,
        bytes[] calldata datas
    ) external onlyOwner returns (bytes20[] memory) {
        require(
            objects.length == datas.length,
            "DTAG: objects length not equal with datas"
        );

        Common.TagClass memory tagClass = this.getTagClass(tagClassId);
        require(tagClass.Owner != address(0), "invalid tagClassId");
        require(
            checkTagIssuerAuth(sender, tagClass),
            "DTAG: invalid tagClass issuer auth"
        );

        Common.TagFieldType[] memory fieldTypes = Utils.getFieldTypes(
            tagClass.Fields
        );
        bool canMultiIssue = Utils.canMultiIssue(tagClass.Flags);

        bytes20[] memory tagIds = new bytes20[](objects.length);
        for (uint256 i = 0; i < objects.length; i++) {
            bytes20 tagId = Utils.genTagId(
                tagClassId,
                objects[i],
                canMultiIssue
            );
            _newTagBatch(sender, tagClassId, tagId, fieldTypes, datas[i]);
            tagIds[i] = tagId;
        }
        return tagIds;
    }

    function _newTagBatch(
        address sender,
        bytes20 classId,
        bytes20 tagId,
        Common.TagFieldType[] memory fieldTypes,
        bytes calldata data
    ) internal {
        require(!this.has(tagId), "DTAG: tagId has already exist");

        Utils.validateTagData(data, fieldTypes);

        Common.Tag memory tag = Common.Tag(
            uint8(Version),
            classId,
            sender,
            data,
            uint32(block.number)
        );
        _setTag(tagId, tag);
    }

    function updateTag(
        address sender,
        bytes20 tagId,
        bytes calldata data
    ) external onlyOwner {
        Common.Tag memory tag = _getTag(tagId);
        require(tag.ClassId != bytes20(0), "DTAG: invalid tagId");

        Common.TagClass memory tagClass = this.getTagClass(tag.ClassId);
        require(
            tagClass.Owner != address(0),
            "DTAG: invalid tagClassId of tag"
        );
        require(
            checkTagUpdateAuth(sender, tagClass, tag.Issuer),
            "DTAG: invalid tag update auth"
        );

        Common.TagFieldType[] memory fieldTypes = Utils.getFieldTypes(
            tagClass.Fields
        );
        Utils.validateTagData(data, fieldTypes);

        tag.Data = data;
        tag.UpdateAt = uint32(block.number);

        _setTag(tagId, tag);
    }

    function deleteTag(address sender, bytes20 tagId) external onlyOwner {
        Common.Tag memory tag = _getTag(tagId);
        require(tag.ClassId != bytes20(0), "DTAG: invalid tagId");

        Common.TagClass memory tagClass = this.getTagClass(tag.ClassId);
        require(tagClass.Owner != address(0), "DTAG: invalid classId of tag");
        require(
            checkTagUpdateAuth(sender, tagClass, tag.Issuer),
            "DTAG: invalid tag delete auth"
        );

        del(tagId);
    }

    function _getTag(bytes20 tagId)
        internal
        view
        returns (Common.Tag memory tag)
    {
        bytes memory data = this.get(tagId);
        tag = Utils.deserializeTag(data);
        require(tag.Version <= Version, "DTAG: incompatible data version");
        return tag;
    }

    function _setTag(bytes20 tagId, Common.Tag memory tag) internal {
        bytes memory data = Utils.serializeTag(tag);
        set(tagId, data);
    }

    function getTag(bytes20 tagId)
        external
        view
        returns (Common.Tag memory tag, bool valid)
    {
        tag = _getTag(tagId);
        if (tag.ClassId == bytes20(0)) {
            return (tag, valid);
        }
        Common.TagClass memory tagClass = this.getTagClass(tag.ClassId);
        valid =
            tagClass.ExpiredTime == 0 ||
            (uint64(block.number) - tag.UpdateAt) <= tagClass.ExpiredTime;
        return (tag, valid);
    }

    function getTag(bytes20 tagClassId, Common.TagObject calldata object)
        external
        view
        returns (Common.Tag memory tag, bool valid)
    {
        bytes20 tagId = Utils.genTagId(tagClassId, object, false);
        (tag, valid) = this.getTag(tagId);
        if (valid) {
            return (tag, valid);
        }
        if (object.TokenId == uint256(0)) {
            //non-nft
            return (tag, valid);
        }
        Common.TagClass memory tagClass = this.getTagClass(tagClassId);
        if (!Utils.canInherit(tagClass.Flags)) {
            return (tag, valid);
        }
        //check whether inherit from contact
        Common.TagObject memory contractObj;
        contractObj.Address = object.Address;
        tagId = Utils.genTagId(tagClassId, contractObj, false);
        return this.getTag(tagId);
    }

    function hasTag(bytes20 tagClassId, Common.TagObject calldata object)
        external
        view
        returns (bool valid)
    {
        (, valid) = this.getTag(tagClassId, object);
        return valid;
    }
}
