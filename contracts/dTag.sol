// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./WriteBuffer.sol";
import "./ReadBuffer.sol";
import "./strings.sol";
import "hardhat/console.sol";

contract dTag {
    using WriteBuffer for WriteBuffer.buffer;
    using ReadBuffer for ReadBuffer.buffer;
    using strings for *;

    struct TagSchema {
        bytes20 Id; // TagSchema id;
        string TagName;
        address Owner; // user address or contract address
        string Fields; // format fieldName_1:type;fieldName_2:type;fieldName_n:type
        string Desc;
        bool Unique; // If true, an owner can only has one tag of a tagSchema，most case is true.
        uint32 GasFee;
    }

    struct Tag {
        bytes20 Id; //Tag id;
        bytes20 SchemaId;
        address Owner;
        bytes Data;
        uint256 CreateAt;
    }

    event CreateTagSchema(
        bytes20 schemaId,
        string name,
        address owner,
        string fields,
        string desc,
        bool unique,
        uint32 gasFee
    );

    event CreateTag(
        bytes20 schemaId,
        bytes20 id,
        address owner,
        bytes data,
        uint256 createAt
    );

    uint256 nonce;
    mapping(bytes20 => TagSchema) private tagSchemas;
    mapping(bytes20 => Tag) private tags;

    function genTagSchemaId() external returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(52).writeAddress(msg.sender).writeUint(++nonce);
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function genTagId(
        bytes20 schemaId,
        address receiver,
        bool unique
    ) external returns (bytes20 id) {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(72).writeBytes20(schemaId).writeAddress(receiver);
        if (!unique) {
            wBuf.writeUint(++nonce);
        }
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function genUniqueTagId(bytes20 schemaId, address receiver)
        external
        pure
        returns (bytes20 id)
    {
        WriteBuffer.buffer memory wBuf;
        wBuf.init(40).writeBytes20(schemaId).writeAddress(receiver);
        return bytes20(keccak256(wBuf.getBytes()));
    }

    function getFieldTypes(string memory fieldSchema)
        public
        pure
        returns (bytes[] memory)
    {
        strings.slice memory fields = fieldSchema.toSlice();
        require(!fields.empty(), "fields cannot empty");

        strings.slice memory delim1 = ";".toSlice();
        strings.slice memory delim2 = ":".toSlice();
        strings.slice memory field;
        strings.slice memory item;
        bytes[] memory types = new bytes[](fields.count(delim1) + 1);
        uint256 index = 0;
        for (uint256 i = 0; i < types.length; i++) {
            field = fields.split(delim1);
            require(!field.empty(), "field cannot empty");

            item = field.split(delim2);
            require(!item.empty(), "field name cannot empty");

            item = field.split(delim2);
            require(!item.empty(), "field type cannot empty");
            types[index++] = bytes(item.toString());

            item = field.split(delim2);
            require(item.empty(), "invalid field type");
        }
        return types;
    }

    function validateFieldTypes(bytes[] memory types) public pure {
        for (uint256 i = 0; i < types.length; i++) {
            bytes32 fieldType = keccak256(types[i]);
            require(
                fieldType == keccak256(bytes("string")) ||
                    fieldType == keccak256(bytes("bytes")) ||
                    fieldType == keccak256(bytes("bytes1")) ||
                    fieldType == keccak256(bytes("bytes2")) ||
                    fieldType == keccak256(bytes("bytes4")) ||
                    fieldType == keccak256(bytes("bytes8")) ||
                    fieldType == keccak256(bytes("bytes20")) ||
                    fieldType == keccak256(bytes("bytes32")) ||
                    fieldType == keccak256(bytes("uint")) ||
                    fieldType == keccak256(bytes("uint8")) ||
                    fieldType == keccak256(bytes("uint16")) ||
                    fieldType == keccak256(bytes("uint32")) ||
                    fieldType == keccak256(bytes("uint64")) ||
                    fieldType == keccak256(bytes("int")) ||
                    fieldType == keccak256(bytes("int8")) ||
                    fieldType == keccak256(bytes("int16")) ||
                    fieldType == keccak256(bytes("int32")) ||
                    fieldType == keccak256(bytes("int64")) ||
                    fieldType == keccak256(bytes("bool")) ||
                    fieldType == keccak256(bytes("address")),
                "contain invalid field type"
            );
        }
    }

    modifier validateTagSchema(string memory fields) {
        bytes[] memory fieldTypes = this.getFieldTypes(fields);
        this.validateFieldTypes(fieldTypes);
        _;
    }

    function validateTagData(bytes memory data, bytes[] memory fieldTypes)
        public
        pure
    {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(data);
        for (uint256 i = 0; i < fieldTypes.length; i++) {
            bytes32 fieldType = keccak256(fieldTypes[i]);
            if (
                fieldType == keccak256(bytes("string")) ||
                fieldType == keccak256(bytes("bytes"))
            ) {
                rBuf.forwardBytes();
            } else if (
                fieldType == keccak256(bytes("bytes1")) ||
                fieldType == keccak256(bytes("uint8")) ||
                fieldType == keccak256(bytes("int8")) ||
                fieldType == keccak256(bytes("bool"))
            ) {
                rBuf.forward(1);
            } else if (
                fieldType == keccak256(bytes("bytes2")) ||
                fieldType == keccak256(bytes("uint16")) ||
                fieldType == keccak256(bytes("int16"))
            ) {
                rBuf.forward(2);
            } else if (
                fieldType == keccak256(bytes("bytes4")) ||
                fieldType == keccak256(bytes("uint32")) ||
                fieldType == keccak256(bytes("int32"))
            ) {
                rBuf.forward(4);
            } else if (
                fieldType == keccak256(bytes("bytes8")) ||
                fieldType == keccak256(bytes("uint64")) ||
                fieldType == keccak256(bytes("int64"))
            ) {
                rBuf.forward(8);
            } else if (
                fieldType == keccak256(bytes("bytes20")) ||
                fieldType == keccak256(bytes("address"))
            ) {
                rBuf.forward(20);
            } else if (
                fieldType == keccak256(bytes("bytes32")) ||
                fieldType == keccak256(bytes("uint")) ||
                fieldType == keccak256(bytes("int"))
            ) {
                rBuf.forward(32);
            }
        }
        require(rBuf.left() == 0, "invalid tag data");
    }

    function createTagSchema(
        string calldata tagName,
        string calldata fields,
        string calldata desc,
        bool unique,
        uint32 gasFee
    ) external validateTagSchema(fields) {
        TagSchema memory schema = TagSchema(
            this.genTagSchemaId(),
            tagName,
            msg.sender,
            fields,
            desc,
            unique,
            gasFee
        );
        tagSchemas[schema.Id] = schema;
        emit CreateTagSchema(
            schema.Id,
            schema.TagName,
            schema.Owner,
            schema.Fields,
            schema.Desc,
            schema.Unique,
            schema.GasFee
        );
    }

    function getTagSchema(bytes20 tagSchemaId)
        external
        view
        returns (TagSchema memory)
    {
        return tagSchemas[tagSchemaId];
    }

    function createTagToUser(
        bytes20 tagSchemaId,
        address receiver,
        bytes calldata data
    ) external {
        TagSchema memory tagSchema = tagSchemas[tagSchemaId];
        require(tagSchema.Id != bytes20(0), "invalid tagSchemaId");

        bytes20 tagId = this.genTagId(tagSchemaId, receiver, tagSchema.Unique);
        Tag storage tag = tags[tagId];
        require(
            tagSchema.Unique && tag.Id == bytes20(0),
            "tag has already exist"
        );

        bytes[] memory fieldTypes = this.getFieldTypes(tagSchema.Fields);
        this.validateTagData(data, fieldTypes);

        tag.Owner = msg.sender;
        tag.Data = data;
        tag.SchemaId = tagSchemaId;
        tag.Id = tagId;
        tag.CreateAt = block.number;

        emit CreateTag(tag.SchemaId, tag.Id, tag.Owner, tag.Data, tag.CreateAt);
    }

    function getTag(bytes20 tagId) external view returns (Tag memory) {
        Tag memory tag = tags[tagId];
        return tag;
    }

    function getTag(address addr, bytes20 tagSchemaId)
        external
        view
        returns (Tag memory)
    {
        Tag memory tag = tags[this.genUniqueTagId(tagSchemaId, addr)];
        return tag;
    }

    function hasTag(address addr, bytes20 tagSchemaId)
        external
        view
        returns (bool)
    {
        Tag memory tag = tags[this.genUniqueTagId(tagSchemaId, addr)];
        return tag.Id != bytes20(0);
    }

    function createTagToContact(
        address tagSchemaId,
        address contractAddress,
        bytes calldata data
    ) external {}

    function createTagToNFT(
        address tagSchemaId,
        address contractAddress,
        string calldata assetId,
        bytes calldata data
    ) external {}

    function createTagToTagSchema(
        address tagSchemaId,
        address destTagSchemaId,
        bytes calldata data
    ) external {}
}
