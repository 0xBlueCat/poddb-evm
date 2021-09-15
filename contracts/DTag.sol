// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./WriteBuffer.sol";
import "./ReadBuffer.sol";
import "./Common.sol";
import "./Utils.sol";
import "./DTagClass.sol";
import "./Owner.sol";

abstract contract Storage {
    function has(bytes20 id) external view virtual returns (bool);

    function get(bytes20 id) external view virtual returns (bytes memory);

    function set(bytes20 id, bytes calldata data) external virtual;

    function del(bytes20 id) external virtual;
}

contract DTag is DTagClass {
    using WriteBuffer for WriteBuffer.buffer;
    using ReadBuffer for ReadBuffer.buffer;
    using Common for *;
    using Utils for *;

    event NewTag(
        uint8 version,
        Common.TagObject object,
        bytes20 tagClassId,
        bytes20 id,
        address issuer,
        bytes data
    );

    event UpdateTag(bytes20 id, bytes data);
    event DeleteTag(bytes20 id);

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

    function checkTagClassUpdateAuth(Common.TagClass memory tagClass)
        internal
        view
        override
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
        if (tagClass.Agent.Type == Common.AgentType.Address) {
            return tagClass.Agent.Agent == bytes20(msg.sender);
        }
        Common.TagObject memory object = Common.TagObject(
            msg.sender,
            uint256(0)
        );
        return this.hasTag(tagClass.Agent.Agent, object);
    }

    function checkTagClassIssuerAuth(Common.TagClass memory tagClass)
        internal
        view
        override
        returns (bool)
    {
        if (Common.isPublic(tagClass.Flags)) {
            return true;
        }
        return checkTagClassUpdateAuth(tagClass);
    }

    function checkTagUpdateAuth(
        Common.TagClass memory tagClass,
        address tagIssuer
    ) internal view returns (bool) {
        if (Common.isPublic(tagClass.Flags)) {
            return tagIssuer == msg.sender;
        }
        return checkTagClassUpdateAuth(tagClass);
    }

    function newTag(
        bytes20 tagClassId,
        Common.TagObject calldata object,
        bytes calldata data
    ) external onlyOwner{
        Common.TagClass memory tagClass = this.getTagClass(tagClassId);
        require(tagClass.Owner != address(0), "invalid tagClassId");

        require(
            checkTagClassIssuerAuth(tagClass),
            "invalid tagClass issuer permission"
        );

        Common.TagFieldType[] memory fieldTypes = Utils.getFieldTypes(
            tagClass.Fields
        );
        Utils.validateTagData(data, fieldTypes);

        bytes20 tagId = Utils.genTagId(
            tagClassId,
            object,
            Common.canMultiIssue(tagClass.Flags)
        );

        require(!this.has(tagId), "tagId has already exist");

        Common.Tag memory tag = Common.Tag(
            uint8(Version),
            tagClassId,
            msg.sender,
            data,
            uint32(block.number)
        );

        _setTag(tagId, tag);

        emit NewTag(
            uint8(Version),
            object,
            tagClassId,
            tagId,
            tag.Issuer,
            data
        );
    }

    function newTagBatch(
        bytes20 tagClassId,
        Common.TagObject[] calldata objects,
        bytes[] calldata datas
    ) external onlyOwner{
        require(
            objects.length == datas.length,
            "objects length not equal with datas"
        );

        Common.TagClass memory tagClass = this.getTagClass(tagClassId);
        require(tagClass.Owner != address(0), "invalid tagClassId");
        require(
            checkTagClassIssuerAuth(tagClass),
            "invalid tagClass issuer permission"
        );

        Common.TagFieldType[] memory fieldTypes = Utils.getFieldTypes(
            tagClass.Fields
        );
        bool canMultiIssue = Common.canMultiIssue(tagClass.Flags);
        uint32 updateAt = uint32(block.number);
        address owner = msg.sender;
        bytes20 tagId;

        for (uint256 i = 0; i < objects.length; i++) {
            tagId = Utils.genTagId(tagClassId, objects[i], canMultiIssue);
            require(!this.has(tagId), "tagId has already exist");

            Utils.validateTagData(datas[i], fieldTypes);

            Common.Tag memory tag = Common.Tag(
                uint8(Version),
                tagClassId,
                owner,
                datas[i],
                updateAt
            );
            _setTag(tagId, tag);

            emit NewTag(
                uint8(Version),
                objects[i],
                tagClassId,
                tagId,
                owner,
                datas[i]
            );
        }
    }

    function updateTag(bytes20 tagId, bytes calldata data) external onlyOwner{
        Common.Tag memory tag = _getTag(tagId);
        require(tag.ClassId != bytes20(0), "invalid tagId");

        Common.TagClass memory tagClass = this.getTagClass(tag.ClassId);
        require(tagClass.Owner != address(0), "invalid tagClassId of tag");
        require(
            checkTagUpdateAuth(tagClass, tag.Issuer),
            "invalid tag update permission"
        );

        Common.TagFieldType[] memory fieldTypes = Utils.getFieldTypes(
            tagClass.Fields
        );
        Utils.validateTagData(data, fieldTypes);

        tag.Data = data;
        tag.UpdateAt = uint32(block.number);

        _setTag(tagId, tag);

        emit UpdateTag(tagId, data);
    }

    function deleteTag(bytes20 tagId) external onlyOwner{
        Common.Tag memory tag = _getTag(tagId);
        require(tag.ClassId != bytes20(0), "invalid tagId");

        Common.TagClass memory tagClass = this.getTagClass(tag.ClassId);
        require(tagClass.Owner != address(0), "invalid classId of tag");
        require(
            checkTagUpdateAuth(tagClass, tag.Issuer),
            "invalid tag delete permission"
        );

        del(tagId);

        emit DeleteTag(tagId);
    }

    function _getTag(bytes20 tagId)
        internal
        view
        returns (Common.Tag memory tag)
    {
        bytes memory data = this.get(tagId);
        tag = Common.deserializeTag(data);
        require(tag.Version <= Version, "compatible version");
        return tag;
    }

    function _setTag(bytes20 tagId, Common.Tag memory tag) internal {
        bytes memory data = Common.serializeTag(tag);
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
        bytes20 tagId = Utils.genTagId(tagClassId, object, true);
        (tag, valid) = this.getTag(tagId);
        if (valid) {
            return (tag, valid);
        }
        if (object.TokenId == uint256(0)) {
            //non-nft
            return (tag, valid);
        }
        Common.TagClass memory tagClass = this.getTagClass(tagClassId);
        if (!Common.canInherit(tagClass.Flags)) {
            return (tag, valid);
        }
        //check whether inherit from contact
        Common.TagObject memory contractObj;
        contractObj.Address = object.Address;
        tagId = Utils.genTagId(tagClassId, contractObj, true);
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
