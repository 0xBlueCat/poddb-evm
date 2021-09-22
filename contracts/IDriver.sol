// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "./IPodDB.sol";

interface IDriver {
    function setTagClass(IPodDB.TagClass calldata tagClass) external;

    function setTagClassInfo(IPodDB.TagClassInfo calldata tagClassInfo)
        external;

    function setTagClassAll(
        IPodDB.TagClass calldata tagClass,
        IPodDB.TagClassInfo calldata tagClassInfo
    ) external;

    function hasTagClass(bytes20 classId) external view returns (bool);

    function hasTagClassInfo(bytes20 classId) external view returns (bool);

    function deleteTagClass(bytes20 classId) external;

    function deleteTagClassInfo(bytes20 classId) external;

    function getTagClass(bytes20 classId, uint8 version)
        external
        view
        returns (IPodDB.TagClass memory tagClass);

    function getTagClassInfo(bytes20 tagClassId, uint8 version)
        external
        view
        returns (IPodDB.TagClassInfo memory classInfo);

    function setTag(IPodDB.Tag calldata tag) external;

    function getTag(bytes20 tagId, uint8 version)
        external
        view
        returns (IPodDB.Tag memory tag);

    function hasTag(bytes20 tagId) external view returns (bool);

    function deleteTag(bytes20 tagId) external;
}
