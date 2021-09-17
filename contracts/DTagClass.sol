// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./WriteBuffer.sol";
import "./ReadBuffer.sol";
import "./Common.sol";
import "./Utils.sol";
import "./librarys/Ownable.sol";

abstract contract DTagClass is Ownable {
    using WriteBuffer for WriteBuffer.buffer;
    using ReadBuffer for ReadBuffer.buffer;
    using Common for *;
    using Utils for *;

    uint256 constant Version = 1;

    constructor() Ownable() {}

    function has(bytes20 id) external view virtual returns (bool);

    function get(bytes20 id) external view virtual returns (bytes memory);

    function set(bytes20 id, bytes memory data) internal virtual;

    function del(bytes20 id) internal virtual;

    function setTagClass(
        address sender,
        bytes20 classId,
        bytes memory fields,
        uint8 flags,
        uint32 expiredTime,
        Common.TagAgent calldata agent
    ) internal {
        Common.TagClass memory tagClass = Common.TagClass(
            uint8(Version),
            sender,
            fields,
            flags,
            expiredTime,
            agent
        );
        set(classId, Utils.serializeTagClass(tagClass));
    }

    function checkTagClassUpdateAuth(
        address sender,
        Common.TagClass memory tagClass
    ) internal view virtual returns (bool);

    function newTagClass(
        address sender,
        string calldata tagName,
        bytes calldata fields,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        Common.TagAgent calldata agent
    ) external onlyOwner returns (bytes20) {
        require(bytes(tagName).length > 0, "DTAGCLASS: tagName cannot empty");
        Utils.validateTagClassFields(fields);

        bytes20 classId = Utils.genTagClassId();
        require(!this.has(classId), "DTAGCLASS: tagClassId has already exist");

        setTagClass(sender, classId, fields, flags, expiredTime, agent);
        setTagClassInfo(classId, tagName, desc, uint32(block.number));
        return classId;
    }

    function setTagClassInfo(
        bytes20 classId,
        string calldata tagName,
        string calldata desc,
        uint32 createAt
    ) internal {
        bytes20 id = Utils.genTagClassInfoId(classId);
        Common.TagClassInfo memory classInfo = Common.TagClassInfo(
            uint8(Version),
            tagName,
            desc,
            createAt
        );
        bytes memory data = Utils.serializeTagClassInfo(classInfo);
        set(id, data);
    }

    function updateTagClass(
        address sender,
        bytes20 classId,
        string calldata tagName,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        Common.TagAgent calldata agent
    ) external onlyOwner {
        Common.TagClass memory class = this.getTagClass(classId);
        require(class.Owner != address(0), "DTAGCLASS: invalid tagClassId");

        if (agent.Agent != bytes20(0)) {
            require(
                class.Owner == sender,
                "DTAGCLASS: only owner can update tag class agent"
            );
        } else {
            require(
                checkTagClassUpdateAuth(sender, class),
                "DTAGCLASS: invalid tag class update auth"
            );
        }

        setTagClass(sender, classId, class.Fields, flags, expiredTime, agent);

        Common.TagClassInfo memory classInfo = this.getTagClassInfo(classId);
        setTagClassInfo(classId, tagName, desc, classInfo.CreateAt);
    }

    function getTagClass(bytes20 tagClassId)
        external
        view
        returns (Common.TagClass memory tagClass)
    {
        bytes memory data = this.get(tagClassId);
        tagClass = Utils.deserializeTagClass(data);
        require(
            tagClass.Version <= Version,
            "DTAGCLASS: incompatible data version"
        );
        return tagClass;
    }

    function getTagClassInfo(bytes20 tagClassId)
        external
        view
        returns (Common.TagClassInfo memory classInfo)
    {
        bytes memory data = this.get(Utils.genTagClassInfoId(tagClassId));
        classInfo = Utils.deserializeTagClassInfo(data);
        require(
            classInfo.Version <= Version,
            "DTAGCLASS: incompatible data version"
        );
        return classInfo;
    }
}
