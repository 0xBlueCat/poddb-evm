// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./WriteBuffer.sol";
import "./ReadBuffer.sol";
import "./dTagCommon.sol";
import "./dTagUtils.sol";

abstract contract dTagSchema {
    using WriteBuffer for WriteBuffer.buffer;
    using ReadBuffer for ReadBuffer.buffer;
    using dTagCommon for *;
    using dTagUtils for *;

    uint8 Version = 1;

    event CreateTagSchema(
        uint8 version,
        bytes20 schemaId,
        string name,
        address owner,
        bytes fields,
        string desc,
        uint8 flags,
        uint32 expiredTime,
        dTagCommon.TagAgent agent
    );

    event UpdateTagSchema(
        bytes20 schemaId,
        string name,
        string desc,
        uint8 flags,
        dTagCommon.TagAgent agent
    );

    event DeleteTagSchema(bytes20 schemaId);

    modifier validateTagSchema(bytes memory fieldTypes) {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(fieldTypes);
        uint256 len = rBuf.readUint8();
        for (uint256 i = 0; i < len; i++) {
            require(rBuf.skipString() > 0, "field name cannot empty");
            dTagCommon.TagFieldType(rBuf.readUint8()); // can convert to TagFieldType
        }
        require(rBuf.left() == 0, "invalid fieldTypes");
        _;
    }

    function get(bytes20 id) external view virtual returns (bytes memory);

    function set(bytes20 id, bytes memory data) internal virtual;

    function del(bytes20 id) internal virtual;

    function setTagSchema(
        bytes20 schemaId,
        bytes memory fields,
        uint8 flags,
        uint32 expiredTime,
        dTagCommon.TagAgent calldata agent
    ) internal {
        dTagCommon.TagSchema memory schema = dTagCommon.TagSchema(
            Version,
            msg.sender,
            fields,
            flags,
            expiredTime,
            agent
        );
        set(schemaId, dTagCommon.serializeTagSchema(schema));
    }

    function checkTagSchemaUpdateAuth(dTagCommon.TagSchema memory schema)
        internal
        view
        virtual
        returns (bool);

    function checkTagSchemaIssuerAuth(dTagCommon.TagSchema memory schema)
        internal
        view
        virtual
        returns (bool);

    function checkTagUpdateAuth(
        dTagCommon.TagSchema memory schema,
        address tagIssuer
    ) internal view virtual returns (bool);

    function createTagSchema(
        string calldata tagName,
        bytes calldata fields,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        dTagCommon.TagAgent calldata agent
    ) external validateTagSchema(fields) {
        bytes20 schemaId = dTagUtils.genTagSchemaId();
        setTagSchema(schemaId, fields, flags, expiredTime, agent);
        setTagSchemaInfo(schemaId, tagName, desc, uint32(block.number));

        //to avoid Stack too deep issue
        emitCreateTagSchema(
            schemaId,
            tagName,
            fields,
            desc,
            flags,
            expiredTime,
            agent
        );
    }

    function emitCreateTagSchema(
        bytes20 schemaId,
        string calldata tagName,
        bytes calldata fields,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        dTagCommon.TagAgent calldata agent
    ) private {
        emit CreateTagSchema(
            Version,
            schemaId,
            tagName,
            msg.sender,
            fields,
            desc,
            flags,
            expiredTime,
            agent
        );
    }

    function setTagSchemaInfo(
        bytes20 tagSchemaId,
        string calldata tagName,
        string calldata desc,
        uint32 createAt
    ) internal {
        bytes20 id = dTagUtils.genTagSchemaInfoId(tagSchemaId);
        dTagCommon.TagSchemaInfo memory schemaInfo = dTagCommon.TagSchemaInfo(
            Version,
            tagName,
            desc,
            createAt
        );
        bytes memory data = dTagCommon.serializeTagSchemaInfo(schemaInfo);
        set(id, data);
    }

    function updateTagSchema(
        bytes20 schemaId,
        string calldata tagName,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        dTagCommon.TagAgent calldata agent
    ) external {
        dTagCommon.TagSchema memory schema = this.getTagSchema(schemaId);
        require(schema.Owner != address(0), "invalid schemaId");

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

        setTagSchema(schemaId, schema.Fields, flags, expiredTime, agent);

        dTagCommon.TagSchemaInfo memory schemaInfo = this.getTagSchemaInfo(
            schemaId
        );
        setTagSchemaInfo(schemaId, tagName, desc, schemaInfo.CreateAt);

        emit UpdateTagSchema(schemaId, tagName, desc, flags, agent);
    }

    function getTagSchema(bytes20 tagSchemaId)
        external
        view
        returns (dTagCommon.TagSchema memory schema)
    {
        bytes memory data = this.get(tagSchemaId);
        schema = dTagCommon.deserializeTagSchema(data);
        require(schema.Version <= Version, "compatible version");
        return schema;
    }

    function getTagSchemaInfo(bytes20 tagSchemaId)
        external
        view
        returns (dTagCommon.TagSchemaInfo memory schemaInfo)
    {
        bytes memory data = this.get(dTagUtils.genTagSchemaInfoId(tagSchemaId));
        schemaInfo = dTagCommon.deserializeTagSchemaInfo(data);
        require(schemaInfo.Version <= Version, "compatible version");
        return schemaInfo;
    }
}
