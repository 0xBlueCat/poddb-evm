// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./WriteBuffer.sol";
import "./ReadBuffer.sol";
import "./Common.sol";
import "./Utils.sol";

abstract contract DTagClass {
    using WriteBuffer for WriteBuffer.buffer;
    using ReadBuffer for ReadBuffer.buffer;
    using Common for *;
    using Utils for *;

    uint8 Version = 1;

    event NewTagClass(
        uint8 version,
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

    modifier validateTagClass(bytes memory fieldTypes) {
        ReadBuffer.buffer memory rBuf = ReadBuffer.fromBytes(fieldTypes);
        uint256 len = rBuf.readUint8();
        for (uint256 i = 0; i < len; i++) {
            require(rBuf.skipString() > 0, "field name cannot empty");
            Common.TagFieldType(rBuf.readUint8()); // can convert to TagFieldType
        }
        require(rBuf.left() == 0, "invalid fieldTypes");
        _;
    }

    function has(bytes20 id) external view virtual returns (bool);

    function get(bytes20 id) external view virtual returns (bytes memory);

    function set(bytes20 id, bytes memory data) internal virtual;

    function del(bytes20 id) internal virtual;

    function setTagClass(
        bytes20 classId,
        bytes memory fields,
        uint8 flags,
        uint32 expiredTime,
        Common.TagAgent calldata agent
    ) internal {
        Common.TagClass memory tagClass = Common.TagClass(
            Version,
            msg.sender,
            fields,
            flags,
            expiredTime,
            agent
        );
        set(classId, Common.serializeTagClass(tagClass));
    }

    function checkTagClassUpdateAuth(Common.TagClass memory tagClass)
        internal
        view
        virtual
        returns (bool);

    function checkTagClassIssuerAuth(Common.TagClass memory tagClass)
        internal
        view
        virtual
        returns (bool);

    function newTagClass(
        string calldata tagName,
        bytes calldata fields,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        Common.TagAgent calldata agent
    ) external validateTagClass(fields) {
        bytes20 classId = Utils.genTagClassId();
        require(!this.has(classId), "tagClassId has already exist");

        setTagClass(classId, fields, flags, expiredTime, agent);
        setTagClassInfo(classId, tagName, desc, uint32(block.number));

        //to avoid Stack too deep issue
        emitNewTagClass(
            classId,
            tagName,
            fields,
            desc,
            flags,
            expiredTime,
            agent
        );
    }

    function emitNewTagClass(
        bytes20 classId,
        string calldata tagName,
        bytes calldata fields,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        Common.TagAgent calldata agent
    ) private {
        emit NewTagClass(
            Version,
            classId,
            tagName,
            msg.sender,
            fields,
            desc,
            flags,
            expiredTime,
            agent
        );
    }

    function setTagClassInfo(
        bytes20 classId,
        string calldata tagName,
        string calldata desc,
        uint32 createAt
    ) internal {
        bytes20 id = Utils.genTagClassInfoId(classId);
        Common.TagClassInfo memory classInfo = Common.TagClassInfo(
            Version,
            tagName,
            desc,
            createAt
        );
        bytes memory data = Common.serializeTagClassInfo(classInfo);
        set(id, data);
    }

    function updateTagClass(
        bytes20 classId,
        string calldata tagName,
        string calldata desc,
        uint8 flags,
        uint32 expiredTime,
        Common.TagAgent calldata agent
    ) external {
        Common.TagClass memory class = this.getTagClass(classId);
        require(class.Owner != address(0), "invalid tagClassId");

        if (agent.Agent != bytes20(0)) {
            require(
                class.Owner == msg.sender,
                "only owner can update tag class agent"
            );
        } else {
            require(
                checkTagClassUpdateAuth(class),
                "invalid tag class update permission"
            );
        }

        setTagClass(classId, class.Fields, flags, expiredTime, agent);

        Common.TagClassInfo memory classInfo = this.getTagClassInfo(classId);
        setTagClassInfo(classId, tagName, desc, classInfo.CreateAt);

        emit UpdateTagClass(classId, tagName, desc, flags, agent);
    }

    function getTagClass(bytes20 tagClassId)
        external
        view
        returns (Common.TagClass memory tagClass)
    {
        bytes memory data = this.get(tagClassId);
        tagClass = Common.deserializeTagClass(data);
        require(tagClass.Version <= Version, "compatible version");
        return tagClass;
    }

    function getTagClassInfo(bytes20 tagClassId)
        external
        view
        returns (Common.TagClassInfo memory classInfo)
    {
        bytes memory data = this.get(Utils.genTagClassInfoId(tagClassId));
        classInfo = Common.deserializeTagClassInfo(data);
        require(classInfo.Version <= Version, "compatible version");
        return classInfo;
    }
}
