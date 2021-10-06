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

library WriteBuffer {
    /**
     * @dev Represents a mutable buffer. Buffers have a current value (buf) and
     *      a capacity. The capacity may be longer than the current value, in
     *      which case it can be extended without the need to allocate more memory.
     */
    struct buffer {
        bytes buf;
        uint256 capacity;
    }

    /**
     * @dev Initializes a buffer with an initial capacity.
     * @param buf The buffer to initialize.
     * @param capacity The number of bytes of space to allocate the buffer.
     * @return The buffer, for chaining.
     */
    function init(buffer memory buf, uint256 capacity)
        internal
        pure
        returns (buffer memory)
    {
        if (capacity % 32 != 0) {
            capacity += 32 - (capacity % 32);
        }
        // Allocate space for the buffer data
        buf.capacity = capacity;
        assembly {
            let ptr := mload(0x40)
            mstore(buf, ptr)
            mstore(ptr, 0)
            mstore(0x40, add(32, add(ptr, capacity)))
        }
        return buf;
    }

    /**
     * @dev Initializes a new buffer from an existing bytes object.
     *      Changes to the buffer may mutate the original value.
     * @param b The bytes object to initialize the buffer with.
     * @return A new buffer.
     */
    function fromBytes(bytes memory b) internal pure returns (buffer memory) {
        buffer memory buf;
        buf.buf = b;
        buf.capacity = b.length;
        return buf;
    }

    function resize(buffer memory buf, uint256 capacity) private pure {
        bytes memory oldbuf = buf.buf;
        init(buf, capacity);
        if (oldbuf.length == 0) {
            return;
        }
        writeFixedBytes(buf, oldbuf);
    }

    /**
     * @dev Sets buffer length to 0.
     * @param buf The buffer to truncate.
     * @return The original buffer, for chaining..
     */
    function truncate(buffer memory buf) internal pure returns (buffer memory) {
        assembly {
            let bufPtr := mload(buf)
            mstore(bufPtr, 0)
        }
        return buf;
    }

    function writeFixedBytes(buffer memory buf, bytes memory data)
        internal
        pure
        returns (buffer memory)
    {
        uint256 dataLen = data.length;
        if (buf.buf.length + dataLen > buf.capacity) {
            resize(buf, (buf.buf.length + dataLen) * 2);
        }
        uint256 dest;
        uint256 src;
        assembly {
            //Memory address of buffer data
            let bufPtr := mload(buf)
            //Length of exiting buffer data
            let bufLen := mload(bufPtr)
            //Incr length of buffer
            mstore(bufPtr, add(bufLen, dataLen))
            //Start address
            dest := add(add(bufPtr, 32), bufLen)
            src := add(data, 32)
        }

        for (uint256 size = 0; size < dataLen; size += 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }
        return buf;
    }

    function writeVarUint(
        buffer memory buf,
        uint256 data,
        uint256 len
    ) internal pure returns (buffer memory) {
        require(len <= 32, "uint len cannot larger than 32");

        if (buf.buf.length + len > buf.capacity) {
            resize(buf, (buf.buf.length + len) * 2);
        }

        // Left-align data
        data = data << (8 * (32 - len));
        assembly {
            // Memory address of the buffer data
            let bufPtr := mload(buf)
            // Length of existing buffer data
            let bufLen := mload(bufPtr)
            let dest := add(add(bufPtr, 32), bufLen)
            mstore(dest, data)
            //Incr length of buffer
            mstore(bufPtr, add(bufLen, len))
        }
        return buf;
    }

    function writeVarUintAt(
        buffer memory buf,
        uint256 offset,
        uint256 data,
        uint256 len
    ) internal pure returns (buffer memory) {
        require(offset <= buf.buf.length, "offset out of bound");
        require(len <= 32, "uint len cannot larger than 32");
        uint256 newLen = offset + len;
        if (newLen > buf.capacity) {
            resize(buf, newLen * 2);
        }

        uint256 tmp = len * 8;
        // Left-align data
        data = data << ((32 - len) * 8);
        bytes32 mask = (~bytes32(0) << tmp) >> tmp;
        assembly {
            // Memory address of the buffer data
            let bufPtr := mload(buf)
            // Length of existing buffer data
            let bufLen := mload(bufPtr)
            let dest := add(add(bufPtr, 32), offset)
            mstore(dest, or(data, and(mload(dest), mask)))

            //Update buffer length if we extended it
            if gt(newLen, bufLen) {
                mstore(bufPtr, newLen)
            }
        }
        return buf;
    }

    /**
     * @dev Writes a byte to the buffer. Resizes if doing so would exceed the
     *      capacity of the buffer.
     * @param buf The buffer to append to
     * @param data The data to append.
     * @return The original buffer, for chaining.
     */
    function writeUint8(buffer memory buf, uint8 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarUint(buf, data, 1);
    }

    function writeUint16(buffer memory buf, uint16 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarUint(buf, data, 2);
    }

    function writeUint32(buffer memory buf, uint32 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarUint(buf, data, 4);
    }

    function writeUint64(buffer memory buf, uint64 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarUint(buf, data, 8);
    }

    function writeUint256(buffer memory buf, uint256 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarUint(buf, data, 32);
    }

    function writeInt8(buffer memory buf, int8 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarUint(buf, uint8(data), 1);
    }

    function writeInt16(buffer memory buf, int16 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarUint(buf, uint16(data), 2);
    }

    function writeInt32(buffer memory buf, int32 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarUint(buf, uint32(data), 4);
    }

    function writeInt64(buffer memory buf, int64 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarUint(buf, uint64(data), 8);
    }

    function writeInt256(buffer memory buf, int256 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarUint(buf, uint256(data), 32);
    }

    function writeBytes(buffer memory buf, bytes memory data)
        internal
        pure
        returns (buffer memory)
    {
        writeVarUint(buf, data.length, 2);
        return writeFixedBytes(buf, data);
    }

    function writeVarBytes32(
        buffer memory buf,
        bytes32 data,
        uint256 len
    ) internal pure returns (buffer memory) {
        require(len <= 32, "bytes32 len cannot larger than 32");

        if (buf.buf.length + len > buf.capacity) {
            resize(buf, (buf.buf.length + len) * 2);
        }

        assembly {
            // Memory address of the buffer data
            let bufPtr := mload(buf)
            // Length of existing buffer data
            let bufLen := mload(bufPtr)
            let dest := add(add(bufPtr, 32), bufLen)
            mstore(dest, data)
            //Incr length of buffer
            mstore(bufPtr, add(bufLen, len))
        }
        return buf;
    }

    function writeBytes1(buffer memory buf, bytes1 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarBytes32(buf, data, 1);
    }

    function writeBytes2(buffer memory buf, bytes2 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarBytes32(buf, data, 2);
    }

    function writeBytes4(buffer memory buf, bytes4 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarBytes32(buf, data, 4);
    }

    function writeBytes8(buffer memory buf, bytes8 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarBytes32(buf, data, 8);
    }

    function writeBytes20(buffer memory buf, bytes20 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarBytes32(buf, data, 20);
    }

    function writeBytes32(buffer memory buf, bytes32 data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarBytes32(buf, data, 32);
    }

    function writeBool(buffer memory buf, bool data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarUint(buf, data ? 1 : 0, 1);
    }

    function writeAddress(buffer memory buf, address data)
        internal
        pure
        returns (buffer memory)
    {
        return writeVarBytes32(buf, bytes20(data), 20);
    }

    function writeString(buffer memory buf, string memory data)
        internal
        pure
        returns (buffer memory)
    {
        return writeBytes(buf, bytes(data));
    }

    function getBytes(buffer memory buf) internal pure returns (bytes memory) {
        return buf.buf;
    }

    function length(buffer memory buf) internal pure returns (uint256) {
        return buf.buf.length;
    }
}
