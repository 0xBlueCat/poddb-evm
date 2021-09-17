// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

library Common {
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
        uint8 Version;
        address Owner; // user address or contract address
        bytes Fields; // format Number fieldName_1 fieldType fieldName_2 fieldType fieldName_n fieldType
        // 1:multiIssue flag, means one object have more one tag of this class
        // 2:inherit flag, means when a contract have a tag, all of nft mint by this contact will inherit this tag automatic
        // 4:public flag, means not only the owner of tag class can issuer the tag, other also can issue the tag
        uint8 Flags;
        uint32 ExpiredTime; //expired time(block number) of tag, until tag update, 0 mean tag won't expiration.
        TagAgent Agent;
    }

    struct TagClassInfo {
        uint8 Version;
        string TagName;
        string Desc;
        uint32 CreateAt;
    }

    struct Tag {
        uint8 Version;
        bytes20 ClassId;
        address Issuer;
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
        uint256 TokenId; //NFT tokenId
    }
}
