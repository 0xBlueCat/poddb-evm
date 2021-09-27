// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

interface IPodDB {
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

    struct TagClass {
        bytes20 ClassId;
        uint8 Version;
        address Owner; // user address or contract address
        bytes Fields; // format Number fieldName_1 fieldType fieldName_2 fieldType fieldName_n fieldType
        // 1:multiIssue flag, means one object have more one tag of this class
        // 2:inherit flag, means when a contract have a tag, all of nft mint by this contact will inherit this tag automatic
        uint8 Flags;
        uint32 ExpiredTime; //expired time(block number) of tag, until tag update, 0 mean tag won't expiration.
        TagAgent Agent;
    }

    struct TagClassInfo {
        bytes20 ClassId;
        uint8 Version;
        string TagName;
        string Desc;
        uint32 CreateAt;
    }

    struct Tag {
        bytes20 TagId;
        uint8 Version;
        bytes20 ClassId;
        bytes Data;
        uint32 UpdateAt;
    }

    enum AgentType {
        Address, // user address or contract address,
        Tag //address which had this tag
    }

    //TagClassAgent can delegate tagClass owner permission to another contract or address which had an special tag
    struct TagAgent {
        AgentType Type; //indicate the of the of agent
        bytes20 Agent; //agent have the same permission with the tagClass owner
    }

    struct TagObject {
        address Address; //EOA address, contract address, even tagClassId
        uint256 TokenId; //NFT tokenId, if TokenId != 0, TagObject is NFT, or is a EOA address or contract
    }

    event NewTagClass(
        bytes20 classId,
        string name,
        address owner,
        bytes fields,
        string desc,
        uint8 flags,
        uint32 expiredTime,
        TagAgent agent
    );

    event UpdateTagClass(
        bytes20 indexed classId,
        address owner,
        uint8 flags,
        uint32 expiredTime,
        TagAgent agent
    );

    event UpdateTagClassInfo(bytes20 indexed classId, string name, string desc);

    event SetTag(
        bytes20 id,
        TagObject object,
        bytes20 tagClassId,
        bytes data,
        address issuer
    );

    event DeleteTag(bytes20 id);

    function newTagClass(
        string calldata tagName,
        bytes calldata fields,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        TagAgent calldata agent
    ) external returns (bytes20);

    function updateTagClass(
        bytes20 classId,
        address newOwner,
        uint8 flags,
        uint32 expiredTime,
        TagAgent calldata newAgent
    ) external;

    function updateTagClassInfo(
        bytes20 classId,
        string calldata tagName,
        string calldata desc
    ) external;

    function setTag(
        bytes20 tagClassId,
        TagObject calldata object,
        bytes calldata data
    ) external returns (bytes20);

    function setTagBatch(
        bytes20 tagClassId,
        TagObject[] calldata objects,
        bytes[] calldata datas
    ) external returns (bytes20[] memory);

    function deleteTag(bytes20 tagId) external;

    function getTagClass(bytes20 tagClassId)
        external
        view
        returns (TagClass memory tagClass);

    function getTagClassInfo(bytes20 tagClassId)
        external
        view
        returns (TagClassInfo memory classInfo);

    function getTagById(bytes20 tagId)
        external
        view
        returns (Tag memory tag, bool valid);

    function getTagByObject(bytes20 tagClassId, TagObject calldata object)
        external
        view
        returns (Tag memory tag, bool valid);

    function hasTag(bytes20 tagClassId, TagObject calldata object)
        external
        view
        returns (bool valid);
}
