import { ethers } from "ethers";

export class WriteBuffer {
  private buf: Uint8Array;
  private off: number;
  constructor(cap = 256) {
    this.buf = new Uint8Array(new ArrayBuffer(cap));
    this.off = 0;
  }

  resize(size: number): WriteBuffer {
    if (size < this.buf.byteLength) {
      throw Error("new size should larger than current cap when resize");
    }
    let newBuf = new Uint8Array(new ArrayBuffer(size));
    newBuf.set(this.buf);
    this.buf = newBuf;
    return this;
  }

  writeVarUint(dataUint: number | ethers.BigNumber, len: number): WriteBuffer {
    if (len <= 0 || len > 32) {
      throw new Error("len out of range (0, 32]");
    }
    if (this.buf.byteLength < this.off + len) {
      this.resize((this.off + len) * 2);
    }
    const data = ethers.utils.arrayify(dataUint);
    if (data.length <= len) {
      this.buf.set(ethers.utils.zeroPad(data, len), this.off);
    } else {
      this.buf.set(data.slice(data.length - len), this.off);
    }
    this.off += len;
    return this;
  }

  writeVarBytes32(
    dataHexString: string | ethers.BytesLike,
    len: number
  ): WriteBuffer {
    if (len <= 0 || len > 32) {
      throw new Error("len out of range (0, 32]");
    }
    if (this.buf.byteLength < this.off + len) {
      this.resize((this.off + len) * 2);
    }
    const data = ethers.utils.arrayify(dataHexString);
    if (data.length >= len) {
      this.buf.set(data.slice(0, len), this.off);
    } else {
      const tmp = new Uint8Array(len);
      tmp.set(data);
      this.buf.set(tmp, this.off);
    }
    this.off += len;
    return this;
  }

  writeFixedBytes(dataHexString: string | ethers.BytesLike): WriteBuffer {
    const data = ethers.utils.arrayify(dataHexString);
    if (this.buf.byteLength < this.off + data.length) {
      this.resize((this.off + data.length) * 2);
    }
    this.buf.set(data, this.off);
    this.off += data.length;
    return this;
  }

  writeBytes(dataHexString: string | ethers.BytesLike): WriteBuffer {
    const data = ethers.utils.arrayify(dataHexString);
    this.writeUint16(data.byteLength);
    this.writeFixedBytes(dataHexString);
    return this;
  }

  writeBytes1(dataHexString: string | ethers.BytesLike): WriteBuffer {
    this.writeVarBytes32(dataHexString, 1);
    return this;
  }

  writeBytes2(dataHexString: string | ethers.BytesLike): WriteBuffer {
    this.writeVarBytes32(dataHexString, 2);
    return this;
  }

  writeBytes4(dataHexString: string | ethers.BytesLike): WriteBuffer {
    this.writeVarBytes32(dataHexString, 4);
    return this;
  }

  writeBytes8(dataHexString: string | ethers.BytesLike): WriteBuffer {
    this.writeVarBytes32(dataHexString, 8);
    return this;
  }

  writeBytes20(dataHexString: string | ethers.BytesLike): WriteBuffer {
    this.writeVarBytes32(dataHexString, 20);
    return this;
  }

  writeBytes32(dataHexString: string | ethers.BytesLike): WriteBuffer {
    this.writeVarBytes32(dataHexString, 32);
    return this;
  }

  writeUint8(dataUint8: number | ethers.BigNumber): WriteBuffer {
    this.writeVarUint(dataUint8, 1);
    return this;
  }

  writeUint16(dataUint16: number | ethers.BigNumber): WriteBuffer {
    this.writeVarUint(dataUint16, 2);
    return this;
  }

  writeUint32(dataUint32: number | ethers.BigNumber): WriteBuffer {
    this.writeVarUint(dataUint32, 4);
    return this;
  }

  writeUint64(dataUint64: number | ethers.BigNumber): WriteBuffer {
    this.writeVarUint(dataUint64, 8);
    return this;
  }

  writeUint(dataUint: number | ethers.BigNumber): WriteBuffer {
    this.writeVarUint(dataUint, 32);
    return this;
  }

  //
  // writeInt8(dataInt8){
  //     this.writeVarUint(dataInt8,1);
  // }
  //
  // writeInt16(dataInt16){
  //     this.writeVarUint(dataInt16, 2);
  // }
  //
  // writeInt32(dataInt32){
  //     this.writeVarUint(dataInt32, 4);
  // }
  //
  // writeInt64(dataInt64){
  //     this.writeVarUint(dataInt64, 8);
  // }
  //
  // writeInt(dataInt){
  //     this.writeVarUint(dataInt, 32);
  // }
  //

  writeAddress(addressHexString: string | ethers.BytesLike): WriteBuffer {
    this.writeBytes20(addressHexString);
    return this;
  }

  writeBool(dataBool: boolean): WriteBuffer {
    this.writeUint8(dataBool ? 1 : 0);
    return this;
  }

  writeString(dataString: string): WriteBuffer {
    this.writeBytes(ethers.utils.toUtf8Bytes(dataString));
    return this;
  }

  getBytes(): string {
    return ethers.utils.hexlify(this.buf.slice(0, this.off));
  }

  length(): number {
    return this.buf.length;
  }
}
