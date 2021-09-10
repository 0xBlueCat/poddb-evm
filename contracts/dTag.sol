// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./WriteBuffer.sol";
import "./ReadBuffer.sol";

contract dTag {
    using WriteBuffer for WriteBuffer.buffer;
    using ReadBuffer for ReadBuffer.buffer;

    enum TagFieldType {
        Bool,
        Uint,
        Uint8,
        Uint16,
        Uint32,
        Uint64,
        Int,
        Int8,
        Int16,
        Int32,
        Int64,
        Bytes1,
        Bytes2,
        Bytes3,
        Bytes4,
        Bytes8,
        Bytes20,
        Bytes32,
        Address,
        Bytes,
        String
    }

    struct TagSchema {
        bytes20 Id; // TagSchema id;
        string TagName;
        address Owner; // user address or contract address
        bytes Fields; // format Number fieldName_1 fieldType fieldName_2 fieldType fieldName_n fieldType
        string Desc;
        bool Unique; // If true, an owner can only has one tag of a tagSchema，most case is true.
        bool IsPublic; //where tag issuer must be the Owner of TagSchema, if TagSchema is public, every one can issue the tag
        uint32 Count; // tag count of current schema
        uint32 ExpiredTime; //expired time of tag, until tag update, 0 mean tag won't expiration.
        uint32 GasFee;
        uint64 CreateAt;
        TagAgent Agent;
    }

    struct Tag {
        bytes20 Id; //Tag id
        bytes20 SchemaId;
        address Issuer;
        bytes Data;
        uint64 UpdateAt;
    }

    enum AgentType {
        Address, // user address or contract address,
        Tag //address which had this tag
    }

    //TagSchemaAgent can delegate tagSchema owner permission to another contract or address which had an special tag
    struct TagAgent {
        AgentType Type; //indicate the of delegator
        bytes20 Agent; //agent have the same permission with the tagSchema owner
    }

    event CreateTagSchema(
        bytes20 schemaId,
        string name,
        address owner,
        bytes fields,
        string desc,
        bool unique,
        bool isPublic,
        uint32 expiredTime,
        uint32 gasFee,
        TagAgent agent
    );

    event UpdateTagSchema(
        bytes20 schemaId,
        string name,
        string desc,
        uint32 gasFee,
        bool isPublic,
        TagAgent agent
    );

    event DeleteTagSchema(bytes20 schemaId);

    event AddTag(
        bytes20 schemaId,
        bytes20 id,
        address owner,
        address issuer,
        bytes data
    );

    event UpdateTag(bytes20 id, bytes data);

    event DeleteTag(bytes20 id);

    mapping(bytes20 => TagSchema) private tagSchemas;
    mapping(bytes20 => Tag) private tags;

    modifier validateTagSchema(bytes memory fieldTypes) {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(fieldTypes);
        uint256 len = rBuf.readUint8();
        for (uint256 i = 0; i < len; i++) {
            require(rBuf.skipString() > 0, "field name cannot empty");
            TagFieldType(rBuf.readUint8()); // can convert to TagFieldType
        }
        require(rBuf.left() == 0, "invalid fieldTypes");
        _;
    }

    function genTagSchemaId() external view returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(52).writeAddress(msg.sender).writeBytes32(
            blockhash(block.number - 1)
        );
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function genTagId(
        bytes20 schemaId,
        address addr,
        bool unique
    ) external view returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        if (unique) {
            wBuf.init(40).writeBytes20(schemaId).writeAddress(addr);
        } else {
            wBuf
                .init(72)
                .writeBytes20(schemaId)
                .writeAddress(addr)
                .writeBytes32(blockhash(block.number - 1));
        }
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function getFieldTypes(bytes memory fieldTypes)
        public
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

    function validateTagData(
        bytes memory data,
        TagFieldType[] memory fieldTypes
    ) public pure {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(data);
        for (uint256 i = 0; i < fieldTypes.length; i++) {
            TagFieldType fieldType = fieldTypes[i];
            if (
                fieldType == TagFieldType.String ||
                fieldType == TagFieldType.Bytes
            ) {
                rBuf.skipBytes();
            } else if (
                fieldType == TagFieldType.Bytes1 ||
                fieldType == TagFieldType.Uint8 ||
                fieldType == TagFieldType.Int8 ||
                fieldType == TagFieldType.Bool
            ) {
                rBuf.skip(1);
            } else if (
                fieldType == TagFieldType.Bytes2 ||
                fieldType == TagFieldType.Uint16 ||
                fieldType == TagFieldType.Int16
            ) {
                rBuf.skip(2);
            } else if (
                fieldType == TagFieldType.Bytes4 ||
                fieldType == TagFieldType.Uint32 ||
                fieldType == TagFieldType.Int32
            ) {
                rBuf.skip(4);
            } else if (
                fieldType == TagFieldType.Bytes8 ||
                fieldType == TagFieldType.Uint64 ||
                fieldType == TagFieldType.Int64
            ) {
                rBuf.skip(8);
            } else if (
                fieldType == TagFieldType.Bytes20 ||
                fieldType == TagFieldType.Address
            ) {
                rBuf.skip(20);
            } else if (
                fieldType == TagFieldType.Bytes32 ||
                fieldType == TagFieldType.Uint ||
                fieldType == TagFieldType.Int
            ) {
                rBuf.skip(32);
            }
        }
        require(rBuf.left() == 0, "invalid tag data");
    }

    function checkTagSchemaUpdateAuth(TagSchema storage schema)
    internal
    view
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
        if (schema.Agent.Type == AgentType.Address) {
            return schema.Agent.Agent == bytes20(msg.sender);
        }
        return this.hasTag(schema.Agent.Agent, msg.sender);
    }

    function checkTagSchemaIssuerAuth(TagSchema storage schema)
    internal
    view
    returns (bool)
    {
        if (schema.IsPublic) {
            return true;
        }
        return checkTagSchemaUpdateAuth(schema);
    }

    function checkTagUpdateAuth(TagSchema storage schema, address tagIssuer)
    internal
    view
    returns (bool)
    {
        if (schema.IsPublic) {
            return tagIssuer == msg.sender;
        }
        return checkTagSchemaUpdateAuth(schema);
    }

    function createTagSchema(
        string calldata tagName,
        bytes calldata fields,
        string calldata desc,
        bool unique,
        bool isPublic,
        uint32 expiredTime,
        uint32 gasFee,
        TagAgent calldata agent
    ) external validateTagSchema(fields) {
        bytes20 schemaId = this.genTagSchemaId();
        TagSchema storage schema = tagSchemas[schemaId];
        require(schema.Id == bytes32(0), "duplicate schemaId");

        schema.Id = schemaId;
        schema.TagName = tagName;
        schema.Owner = msg.sender;
        schema.Fields = fields;
        schema.Desc = desc;
        schema.Unique = unique;
        schema.IsPublic = isPublic;
        schema.GasFee = gasFee;
        schema.ExpiredTime = expiredTime;
        schema.CreateAt = uint64(block.number);
        schema.Agent = agent;

        tagSchemas[schema.Id] = schema;
        emit CreateTagSchema(
            schema.Id,
            schema.TagName,
            schema.Owner,
            schema.Fields,
            schema.Desc,
            schema.IsPublic,
            schema.Unique,
            schema.ExpiredTime,
            schema.GasFee,
            schema.Agent
        );
    }

    function updateTagSchema(
        bytes20 schemaId,
        string calldata tagName,
        string calldata desc,
        uint32 gasFee,
        bool isPublic,
        TagAgent calldata agent
    ) external {
        TagSchema storage schema = tagSchemas[schemaId];
        require(schema.Id != bytes32(0), "invalid schemaId");

        if (agent.Agent != bytes20(0)) {
            require(
                schema.Owner == msg.sender,
                "only owner can update tag schema agent"
            );
        } else {
            require(
                checkTagSchemaUpdateAuth(schema),
                "invalid tagSchema update permission"
            );
        }

        schema.TagName = tagName;
        schema.Desc = desc;
        schema.GasFee = gasFee;
        schema.IsPublic = isPublic;
        schema.Agent = agent;

        emit UpdateTagSchema(
            schemaId,
            tagName,
            desc,
            gasFee,
            isPublic,
            agent
        );
    }

    function deleteTagSchema(bytes20 schemaId) external {
        TagSchema storage schema = tagSchemas[schemaId];
        require(schema.Id != bytes32(0), "invalid schemaId");
        require(
            checkTagSchemaUpdateAuth(schema),
            "invalid tagSchema update permission"
        );
        require(schema.Count == 0, "only empty tagSchema can be deleted");

        delete tagSchemas[schemaId];

        emit DeleteTagSchema(schemaId);
    }

    function getTagSchema(bytes20 tagSchemaId)
        external
        view
        returns (TagSchema memory)
    {
        return tagSchemas[tagSchemaId];
    }

    function addTagToAddress(
        bytes20 tagSchemaId,
        address addr,
        bytes calldata data
    ) external {
        TagSchema storage tagSchema = tagSchemas[tagSchemaId];
        require(tagSchema.Id != bytes20(0), "invalid tagSchemaId");
        require(
            checkTagSchemaIssuerAuth(tagSchema),
            "invalid tagSchema issuer permission"
        );

        bytes20 tagId = this.genTagId(tagSchemaId, addr, tagSchema.Unique);
        Tag storage tag = tags[tagId];
        require(tag.SchemaId == bytes20(0), "tag has already exist");

        TagFieldType[] memory fieldTypes = this.getFieldTypes(tagSchema.Fields);
        this.validateTagData(data, fieldTypes);

        tag.Id = tagId;
        tag.Issuer = msg.sender;
        tag.Data = data;
        tag.SchemaId = tagSchemaId;
        tag.UpdateAt = uint64(block.number);

        tagSchema.Count++;

        emit AddTag(tag.SchemaId, tagId, addr, tag.Issuer, tag.Data);
    }

    function updateTag(bytes20 tagId, bytes calldata data) external {
        Tag storage tag = tags[tagId];
        require(tag.SchemaId != bytes20(0), "invalid tagId");

        TagSchema storage tagSchema = tagSchemas[tag.SchemaId];
        require(tagSchema.Id != bytes20(0), "invalid tagSchemaId");
        require(
            checkTagUpdateAuth(tagSchema, tag.Issuer),
            "invalid tag update permission"
        );

        TagFieldType[] memory fieldTypes = this.getFieldTypes(tagSchema.Fields);
        this.validateTagData(data, fieldTypes);

        tag.Data = data;
        tag.UpdateAt = uint64(block.number);

        emit UpdateTag(tagId, data);
    }

    function deleteTag(bytes20 tagId) external {
        Tag storage tag = tags[tagId];
        require(tag.SchemaId != bytes20(0), "invalid tagId");

        TagSchema storage tagSchema = tagSchemas[tag.SchemaId];
        require(tagSchema.Id != bytes20(0), "invalid tagSchemaId of tag");
        require(
            checkTagUpdateAuth(tagSchema, tag.Issuer),
            "invalid tag delete permission"
        );

        tagSchema.Count--;
        delete tags[tagId];

        emit DeleteTag(tagId);
    }

    function addTagToNFT(
        bytes20 tagSchemaId,
        address contractAddress,
        string calldata assetId,
        bytes calldata data
    ) external {
        //        TagSchema memory tagSchema = tagSchemas[tagSchemaId];
        //        require(tagSchema.Id != bytes20(0), "invalid tagSchemaId");
    }

    function addTagToTagSchema(
        address tagSchemaId,
        address destTagSchemaId,
        bytes calldata data
    ) external {}

    function getTag(bytes20 tagId)
        external
        view
        returns (Tag memory tag, bool valid)
    {
        tag = tags[tagId];
        if (tag.Id == bytes20(0)) {
            return (tag, valid);
        }
        TagSchema memory tagSchema = tagSchemas[tag.SchemaId];
        valid =
            tagSchema.ExpiredTime == 0 ||
            (uint64(block.number) - tag.UpdateAt) <= tagSchema.ExpiredTime;
        return (tag, valid);
    }

    function getTag(bytes20 tagSchemaId, address addr)
        external
        view
        returns (Tag memory tag, bool valid)
    {
        bytes20 tagId = this.genTagId(tagSchemaId, addr, true);
        return this.getTag(tagId);
    }

    function hasTag(bytes20 tagSchemaId, address addr)
        external
        view
        returns (bool)
    {
        bool valid;
        (, valid) = this.getTag(tagSchemaId,addr);
        return valid;
    }
}
