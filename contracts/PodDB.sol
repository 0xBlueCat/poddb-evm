// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./Common.sol";
import "./librarys/Ownable.sol";

interface ITag {
    function newTagClass(
        address sender,
        string calldata tagName,
        bytes calldata fields,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        Common.TagAgent calldata agent
    ) external returns (bytes20);

    function updateTagClass(
        address sender,
        bytes20 classId,
        string calldata tagName,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        Common.TagAgent calldata agent
    ) external;

    function newTag(
        address sender,
        bytes20 tagClassId,
        Common.TagObject calldata object,
        bytes calldata data
    ) external returns (bytes20);

    function newTagBatch(
        address sender,
        bytes20 tagClassId,
        Common.TagObject[] calldata objects,
        bytes[] calldata datas
    ) external returns (bytes20[] memory);

    function updateTag(
        address sender,
        bytes20 tagId,
        bytes calldata data
    ) external;

    function deleteTag(address sender, bytes20 tagId) external;

    function getTagClass(bytes20 tagClassId)
        external
        view
        returns (Common.TagClass memory tagClass);

    function getTagClassInfo(bytes20 tagClassId)
        external
        view
        returns (Common.TagClassInfo memory classInfo);

    function getTag(bytes20 tagId)
        external
        view
        returns (Common.Tag memory tag, bool valid);

    function getTag(bytes20 tagClassId, Common.TagObject calldata object)
        external
        view
        returns (Common.Tag memory tag, bool valid);

    function hasTag(bytes20 tagClassId, Common.TagObject calldata object)
        external
        view
        returns (bool valid);
}

contract PodDB is Ownable {
    event NewTagClass(
        bytes20 classId,
        string name,
        address owner,
        bytes fields,
        string desc,
        uint8 flags,
        uint32 expiredTime,
        Common.TagAgent agent
    );

    event UpdateTagClass(
        bytes20 classId,
        string name,
        string desc,
        uint8 flags,
        Common.TagAgent agent
    );

    event NewTag(
        Common.TagObject object,
        bytes20 tagClassId,
        bytes20 id,
        address issuer,
        bytes data
    );

    event UpdateTag(bytes20 id, bytes data);

    event DeleteTag(bytes20 id);

    address private tagContract;

    constructor(address _tagContract) Ownable() {
        tagContract = _tagContract;
    }

    function changeTagContract(address _tagContract) external onlyOwner {
        tagContract = _tagContract;
    }

    event test(string msg);

    function newTagClass(
        string calldata tagName,
        bytes calldata fields,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        Common.TagAgent calldata agent
    ) external returns (bytes20 classId) {
        ITag tagC = ITag(tagContract);
        classId = tagC.newTagClass(
            msg.sender,
            tagName,
            fields,
            desc,
            flags,
            expiredTime,
            agent
        );
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

    function updateTagClass(
        bytes20 classId,
        string calldata tagName,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        Common.TagAgent calldata agent
    ) external {
        ITag tagC = ITag(tagContract);
        tagC.updateTagClass(
            msg.sender,
            classId,
            tagName,
            desc,
            flags,
            expiredTime,
            agent
        );
        emit UpdateTagClass(classId, tagName, desc, flags, agent);
    }

    function newTag(
        bytes20 tagClassId,
        Common.TagObject calldata object,
        bytes calldata data
    ) external returns (bytes20 tagId) {
        ITag tagC = ITag(tagContract);
        tagId = tagC.newTag(msg.sender, tagClassId, object, data);
        emit NewTag(object, tagClassId, tagId, msg.sender, data);
        return tagId;
    }

    function newTagBatch(
        bytes20 tagClassId,
        Common.TagObject[] calldata objects,
        bytes[] calldata datas
    ) external returns (bytes20[] memory tagIds) {
        ITag tagC = ITag(tagContract);
        tagIds = tagC.newTagBatch(msg.sender, tagClassId, objects, datas);
        for (uint256 i = 0; i < tagIds.length; i++) {
            emit NewTag(
                objects[i],
                tagClassId,
                tagIds[i],
                msg.sender,
                datas[i]
            );
        }
        return tagIds;
    }

    function updateTag(bytes20 tagId, bytes calldata data) external {
        ITag tagC = ITag(tagContract);
        tagC.updateTag(msg.sender, tagId, data);
        emit UpdateTag(tagId, data);
    }

    function deleteTag(bytes20 tagId) external {
        ITag tagC = ITag(tagContract);
        tagC.deleteTag(msg.sender, tagId);
        emit DeleteTag(tagId);
    }

    function getTagClass(bytes20 tagClassId)
        external
        view
        returns (Common.TagClass memory tagClass)
    {
        ITag tagC = ITag(tagContract);
        return tagC.getTagClass(tagClassId);
    }

    function getTagClassInfo(bytes20 tagClassId)
        external
        view
        returns (Common.TagClassInfo memory classInfo)
    {
        ITag tagC = ITag(tagContract);
        return tagC.getTagClassInfo(tagClassId);
    }

    function getTagById(bytes20 tagId)
        external
        view
        returns (Common.Tag memory tag, bool valid)
    {
        ITag tagC = ITag(tagContract);
        return tagC.getTag(tagId);
    }

    function getTag(bytes20 tagClassId, Common.TagObject calldata object)
        external
        view
        returns (Common.Tag memory tag, bool valid)
    {
        ITag tagC = ITag(tagContract);
        return tagC.getTag(tagClassId, object);
    }

    function hasTag(bytes20 tagClassId, Common.TagObject calldata object)
        external
        view
        returns (bool valid)
    {
        ITag tagC = ITag(tagContract);
        return tagC.hasTag(tagClassId, object);
    }
}
