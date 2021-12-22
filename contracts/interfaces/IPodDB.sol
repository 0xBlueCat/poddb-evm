// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

interface IPodDB {
    enum TagFieldType {
        Bool,
        Uint256,
        Uint8,
        Uint16,
        Uint32,
        Uint64,
        Int256,
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
        String,
        //if a field is array, the must be followed by a filedType, and max elem of array is 65535
        //note that array type doest not support nested array!
        Array
    }

    struct TagClass {
        bytes20 ClassId;
        uint8 Version;
        address Owner; // EOA address or CA address
        bytes FieldTypes; //field types
        //TagClass Flags:
        //0x60:deprecated flag, if a TagClass is marked as deprecated, you cannot set Tag under this TagClass
        uint8 Flags;
        TagAgent Agent;
    }

    struct TagClassInfo {
        bytes20 ClassId;
        uint8 Version;
        string TagName;
        string FieldNames; //name of fields, separate with comma between fields. such as "field1,field2"
        string Desc;
    }

    struct Tag {
        bytes20 TagId;
        uint8 Version;
        bytes20 ClassId;
        uint32 ExpiredAt; //Expired time
        bytes Data;
    }

    enum AgentType {
        Address, // eoa address or ca address,
        Tag //address which have this tag
    }

    //TagClassAgent can delegate tagClass owner permission to agent
    struct TagAgent {
        AgentType Type; //indicate the type of agent
        bytes20 Agent; //agent have the setTag permission
    }

    enum ObjectType {
        Address, // eoa address or ca address
        NFT, // nft
        TagClass // tagClass
    }

    struct TagObject {
        ObjectType Type; //indicate the type of object
        address Address; //EOA address, CA address, or tagClassId
        uint256 TokenId; //NFT tokenId
    }

    event NewTagClass(
        bytes20 indexed classId,
        string name,
        address indexed owner,
        string fieldNames,
        bytes fieldTypes,
        string desc,
        uint8 flags,
        TagAgent agent
    );

    event UpdateTagClass(
        bytes20 indexed classId,
        address indexed owner,
        uint8 flags,
        TagAgent agent
    );

    event UpdateTagClassInfo(bytes20 indexed classId, string name, string desc);

    event SetTag(
        bytes20 indexed id,
        TagObject object,
        bytes20 indexed tagClassId,
        bytes data,
        address issuer,
        uint32 expiredAt,
        uint8 flags
    );

    event DeleteTag(bytes20 indexed id);

    function newTagClass(
        string calldata tagName,
        string calldata fieldNames,
        bytes calldata fieldTypes,
        string calldata desc,
        uint8 flags,
        TagAgent calldata agent
    ) external returns (bytes20);

    function updateTagClass(
        bytes20 classId,
        address newOwner,
        TagAgent calldata newAgent,
        uint8 flags
    ) external;

    function updateTagClassInfo(
        bytes20 classId,
        string calldata tagName,
        string calldata desc
    ) external;

    function setTag(
        bytes20 tagClassId,
        TagObject calldata object,
        bytes calldata data,
        uint32 expiredTime, //Expiration time of tag in seconds, 0 means never expires
        uint8 flags //1 represents a wildcard, and all of NFTs under the target contract will have the Tag
    ) external returns (bytes20 tagId);

    function deleteTag(
        bytes20 tagId,
        bytes20 tagClassId,
        TagObject calldata object
    ) external returns (bool success);

    function getTagClass(bytes20 tagClassId)
        external
        view
        returns (TagClass memory tagClass);

    function getTagClassInfo(bytes20 tagClassId)
        external
        view
        returns (TagClassInfo memory classInfo);

    function getTagByObject(bytes20 tagClassId, TagObject calldata object)
        external
        view
        returns (Tag memory tag, bool valid);

    function hasTag(bytes20 tagClassId, TagObject calldata object)
        external
        view
        returns (bool valid);

    function getTagData(bytes20 tagClassId, TagObject calldata object)
        external
        view
        returns (bytes memory data);
}
