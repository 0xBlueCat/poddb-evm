// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

/**
 * @dev A library for working with mutable byte buffers in Solidity.
 *
 * Byte buffers are mutable and expandable, and provide a variety of primitives
 * for writing to them. At any time you can fetch a bytes object containing the
 * current contents of the buffer. The bytes object should not be stored between
 * operations, as it may change due to resizing of the buffer.
 */
//import "./strings.sol";

library ReadBuffer {
    //    using strings for *;
    /**
     * @dev Represents a mutable buffer. Buffers have a current value (buf) and
     *      a capacity. The capacity may be longer than the current value, in
     *      which case it can be extended without the need to allocate more memory.
     */
    struct buffer {
        bytes buf;
        uint256 off;
    }

    function fromBytes(bytes memory b) internal pure returns (buffer memory) {
        buffer memory buf;
        buf.buf = b;
        return buf;
    }

    function reset(buffer memory buf, bytes memory b) internal pure {
        buf.buf = b;
        buf.off = 0;
    }

    function skip(buffer memory buf, uint256 len) internal pure {
        require(buf.off + len <= buf.buf.length, "skip out of bounds");
        buf.off += len;
    }

    function skipBytes(buffer memory buf) internal pure returns (uint256) {
        uint256 len = readUint16(buf);
        skip(buf, len);
        return len;
    }

    function skipString(buffer memory buf) internal pure returns (uint256) {
        return skipBytes(buf);
    }

    function readFixedBytes(buffer memory buf, uint256 len)
        internal
        pure
        returns (bytes memory)
    {
        uint256 off = buf.off;
        require(
            buf.off + len <= buf.buf.length,
            "readFixedBytes out of bounds"
        );

        bytes memory data = new bytes(len);
        uint256 dest;
        uint256 src;
        assembly {
            // Memory address of the buffer data
            let bufPtr := mload(buf)
            src := add(add(bufPtr, 32), off)
            dest := add(data, 32)
        }

        for (uint256 count = len; count > 0; count -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        buf.off += len;
        return data;
    }

    function readBytes(buffer memory buf) internal pure returns (bytes memory) {
        uint256 len = readUint16(buf);
        return readFixedBytes(buf, len);
    }

    function readVarUint(buffer memory buf, uint256 len)
        internal
        pure
        returns (uint256 data)
    {
        uint256 off = buf.off;
        require(len <= 32, "readVarUint len cannot larger than 32");
        require(buf.off + len <= buf.buf.length, "readVarUint out of bounds");
        assembly {
            // Memory address of the buffer data
            let bufPtr := mload(buf)
            let src := add(add(bufPtr, 32), off)
            data := mload(src)
        }
        data = data >> ((32 - len) * 8);
        buf.off += len;
        return data;
    }

    function readUint8(buffer memory buf) internal pure returns (uint8) {
        return uint8(readVarUint(buf, 1));
    }

    function readUint16(buffer memory buf) internal pure returns (uint16) {
        return uint16(readVarUint(buf, 2));
    }

    function readUint32(buffer memory buf) internal pure returns (uint32) {
        return uint32(readVarUint(buf, 4));
    }

    function readUint64(buffer memory buf) internal pure returns (uint64) {
        return uint64(readVarUint(buf, 8));
    }

    function readUint(buffer memory buf) internal pure returns (uint256) {
        return readVarUint(buf, 32);
    }

    function readInt8(buffer memory buf) internal pure returns (int8) {
        return int8(readUint8(buf));
    }

    function readInt16(buffer memory buf) internal pure returns (int16) {
        return int16(readUint16(buf));
    }

    function readInt32(buffer memory buf) internal pure returns (int32) {
        return int32(readUint32(buf));
    }

    function readInt64(buffer memory buf) internal pure returns (int64) {
        return int64(readUint64(buf));
    }

    function readInt(buffer memory buf) internal pure returns (int256) {
        return int256(readVarUint(buf, 32));
    }

    function readVarBytes32(buffer memory buf, uint256 len)
        internal
        pure
        returns (bytes32 data)
    {
        uint256 off = buf.off;
        require(len <= 32, "readVarBytes32 len cannot larger than 32");
        require(
            buf.off + len <= buf.buf.length,
            "readVarBytes32 out of bounds"
        );
        assembly {
            // Memory address of the buffer data
            let bufPtr := mload(buf)
            let src := add(add(bufPtr, 32), off)
            data := mload(src)
        }
        buf.off += len;
        bytes32 mask = bytes32(~uint256(0)) << ((32 - len) * 8);
        data = data & mask;
        return data;
    }

    function readBytes1(buffer memory buf) internal pure returns (bytes1) {
        return bytes1(readVarBytes32(buf, 1));
    }

    function readBytes2(buffer memory buf) internal pure returns (bytes2) {
        return bytes2(readVarBytes32(buf, 2));
    }

    function readBytes4(buffer memory buf) internal pure returns (bytes4) {
        return bytes4(readVarBytes32(buf, 4));
    }

    function readBytes8(buffer memory buf) internal pure returns (bytes8) {
        return bytes8(readVarBytes32(buf, 8));
    }

    function readBytes20(buffer memory buf) internal pure returns (bytes20) {
        return bytes20(readVarBytes32(buf, 20));
    }

    function readBytes32(buffer memory buf) internal pure returns (bytes32) {
        return readVarBytes32(buf, 32);
    }

    function readAddress(buffer memory buf) internal pure returns (address) {
        return address(bytes20(readVarBytes32(buf, 20)));
    }

    function readBool(buffer memory buf) internal pure returns (bool) {
        return readUint8(buf) > 0 ? true : false;
    }

    function left(buffer memory buf) internal pure returns (uint256) {
        return buf.buf.length - buf.off;
    }
}
