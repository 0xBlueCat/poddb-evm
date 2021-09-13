// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./WriteBuffer.sol";
import "./ReadBuffer.sol";
import "./dTagCommon.sol";
import "./dTagUtils.sol";
import "./dTagSchema.sol";

abstract contract Storage {
    function get(bytes20 id) external view virtual returns (bytes memory);

    function set(bytes20 id, bytes calldata data) external virtual;

    function del(bytes20 id) external virtual;
}

contract dTag is dTagSchema {
    using WriteBuffer for WriteBuffer.buffer;
    using ReadBuffer for ReadBuffer.buffer;
    using dTagCommon for *;
    using dTagUtils for *;

    event AddTag(
        uint8 version,
        dTagCommon.TagObject object,
        bytes20 schemaId,
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

    function genTagId(
        bytes20 schemaId,
        dTagCommon.TagObject memory object,
        bool unique
    ) internal view returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(128).writeBytes20(schemaId).writeAddress(object.Address);
        if (object.TokenId != uint256(0)) {
            wBuf.writeUint(object.TokenId);
        }
        if (!unique) {
            wBuf.writeBytes32(blockhash(block.number - 1));
        }
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function checkTagSchemaUpdateAuth(dTagCommon.TagSchema memory schema)
        internal
        view
        override
        returns (bool)
    {
        if (schema.Owner == msg.sender) {
            return true;
        }
        //check delegator of owner permission
        if (schema.Agent.Agent == bytes20(0)) {
            //no delegator
            return false;
        }
        if (schema.Agent.Type == dTagCommon.AgentType.Address) {
            return schema.Agent.Agent == bytes20(msg.sender);
        }
        dTagCommon.TagObject memory object;
        object.Address = msg.sender;
        return this.hasTag(schema.Agent.Agent, object);
    }

    function checkTagSchemaIssuerAuth(dTagCommon.TagSchema memory schema)
        internal
        view
        override
        returns (bool)
    {
        if (dTagCommon.isPublic(schema.Flags)) {
            return true;
        }
        return checkTagSchemaUpdateAuth(schema);
    }

    function checkTagUpdateAuth(
        dTagCommon.TagSchema memory schema,
        address tagIssuer
    ) internal view returns (bool) {
        if (dTagCommon.isPublic(schema.Flags)) {
            return tagIssuer == msg.sender;
        }
        return checkTagSchemaUpdateAuth(schema);
    }

    function addTag(
        bytes20 tagSchemaId,
        dTagCommon.TagObject calldata object,
        bytes calldata data
    ) external {
        dTagCommon.TagSchema memory tagSchema = this.getTagSchema(tagSchemaId);
        require(tagSchema.Owner != address(0), "invalid tagSchemaId");

        require(
            checkTagSchemaIssuerAuth(tagSchema),
            "invalid tagSchema issuer permission"
        );

        dTagCommon.TagFieldType[] memory fieldTypes = dTagUtils.getFieldTypes(
            tagSchema.Fields
        );
        dTagUtils.validateTagData(data, fieldTypes);

        bytes20 tagId = dTagUtils.genTagId(
            tagSchemaId,
            object,
            dTagCommon.canMultiIssue(tagSchema.Flags)
        );

        dTagCommon.Tag memory tag = dTagCommon.Tag(
            Version,
            tagSchemaId,
            msg.sender,
            data,
            uint32(block.number)
        );

        _setTag(tagId, tag);

        emit AddTag(Version, object, tagSchemaId, tagId, tag.Issuer, data);
    }

    function addTagBatch(
        bytes20 tagSchemaId,
        dTagCommon.TagObject[] calldata objects,
        bytes[] calldata datas
    ) external {
        require(
            objects.length == datas.length,
            "objects length not equal with datas"
        );

        dTagCommon.TagSchema memory tagSchema = this.getTagSchema(tagSchemaId);
        require(tagSchema.Owner != address(0), "invalid tagSchemaId");
        require(
            checkTagSchemaIssuerAuth(tagSchema),
            "invalid tagSchema issuer permission"
        );

        dTagCommon.TagFieldType[] memory fieldTypes = dTagUtils.getFieldTypes(
            tagSchema.Fields
        );
        bool canMultiIssue = dTagCommon.canMultiIssue(tagSchema.Flags);
        uint32 updateAt = uint32(block.number);
        address owner = msg.sender;
        for (uint256 i = 0; i < objects.length; i++) {
            dTagUtils.validateTagData(datas[i], fieldTypes);
            bytes20 tagId = dTagUtils.genTagId(
                tagSchemaId,
                objects[i],
                canMultiIssue
            );
            dTagCommon.Tag memory tag = dTagCommon.Tag(
                Version,
                tagSchemaId,
                owner,
                datas[i],
                updateAt
            );
            _setTag(tagId, tag);
            emit AddTag(
                Version,
                objects[i],
                tagSchemaId,
                tagId,
                owner,
                datas[i]
            );
        }
    }

    function updateTag(bytes20 tagId, bytes calldata data) external {
        dTagCommon.Tag memory tag = _getTag(tagId);
        require(tag.SchemaId != bytes20(0), "invalid tagId");

        dTagCommon.TagSchema memory tagSchema = this.getTagSchema(tag.SchemaId);
        require(tagSchema.Owner != address(0), "invalid tagSchemaId of tag");
        require(
            checkTagUpdateAuth(tagSchema, tag.Issuer),
            "invalid tag update permission"
        );

        dTagCommon.TagFieldType[] memory fieldTypes = dTagUtils.getFieldTypes(
            tagSchema.Fields
        );
        dTagUtils.validateTagData(data, fieldTypes);

        tag.Data = data;
        tag.UpdateAt = uint32(block.number);

        _setTag(tagId, tag);

        emit UpdateTag(tagId, data);
    }

    function deleteTag(bytes20 tagId) external {
        dTagCommon.Tag memory tag = _getTag(tagId);
        require(tag.SchemaId != bytes20(0), "invalid tagId");

        dTagCommon.TagSchema memory tagSchema = this.getTagSchema(tag.SchemaId);
        require(tagSchema.Owner != address(0), "invalid tagSchemaId of tag");
        require(
            checkTagUpdateAuth(tagSchema, tag.Issuer),
            "invalid tag delete permission"
        );

        del(tagId);

        emit DeleteTag(tagId);
    }

    function _getTag(bytes20 tagId)
        internal
        view
        returns (dTagCommon.Tag memory tag)
    {
        bytes memory data = this.get(tagId);
        tag = dTagCommon.deserializeTag(data);
        require(tag.Version <= Version, "compatible version");
        return tag;
    }

    function _setTag(bytes20 tagId, dTagCommon.Tag memory tag) internal {
        bytes memory data = dTagCommon.serializeTag(tag);
        set(tagId, data);
    }

    function getTag(bytes20 tagId)
        external
        view
        returns (dTagCommon.Tag memory tag, bool valid)
    {
        tag = _getTag(tagId);
        if (tag.SchemaId == bytes20(0)) {
            return (tag, valid);
        }
        dTagCommon.TagSchema memory tagSchema = this.getTagSchema(tag.SchemaId);
        valid =
            tagSchema.ExpiredTime == 0 ||
            (uint64(block.number) - tag.UpdateAt) <= tagSchema.ExpiredTime;
        return (tag, valid);
    }

    function getTag(bytes20 tagSchemaId, dTagCommon.TagObject calldata object)
        external
        view
        returns (dTagCommon.Tag memory tag, bool valid)
    {
        bytes20 tagId = dTagUtils.genTagId(tagSchemaId, object, true);
        (tag, valid) = this.getTag(tagId);
        if (valid) {
            return (tag, valid);
        }
        if (object.TokenId == uint256(0)) {
            //non-nft
            return (tag, valid);
        }
        dTagCommon.TagSchema memory tagSchema = this.getTagSchema(tagSchemaId);
        if (!dTagCommon.canInherit(tagSchema.Flags)) {
            return (tag, valid);
        }
        //check whether inherit from contact
        dTagCommon.TagObject memory contractObj;
        contractObj.Address = object.Address;
        tagId = dTagUtils.genTagId(tagSchemaId, contractObj, true);
        return this.getTag(tagId);
    }

    function hasTag(bytes20 tagSchemaId, dTagCommon.TagObject calldata object)
        external
        view
        returns (bool)
    {
        bool valid;
        (, valid) = this.getTag(tagSchemaId, object);
        return valid;
    }
}
