import { ethers } from "ethers";

export class ReadBuffer {
  private buf: Uint8Array;
  private off: number;
  constructor(dataHexString: string | ethers.BytesLike) {
    const data = ethers.utils.arrayify(dataHexString);
    this.buf = new Uint8Array(new ArrayBuffer(data.length));
    this.buf.set(data);
    this.off = 0;
  }

  readVarUint(len: number): ethers.BigNumber {
    if (len <= 0 || len > 32) {
      throw new Error("len out of range (0, 32]");
    }
    if (this.off + len > this.buf.length) {
      throw Error("out of bound");
    }
    const bigNumber = ethers.BigNumber.from(
      ethers.utils.hexlify(this.buf.slice(this.off, this.off + len))
    );
    this.off += len;
    return bigNumber;
  }

  readVarBytes32(len: number): string {
    if (len <= 0 || len > 32) {
      throw new Error("len out of range (0, 32]");
    }
    if (this.off + len > this.buf.length) {
      throw Error("out of bound");
    }
    const dataHexString = ethers.utils.hexlify(
      this.buf.slice(this.off, this.off + len)
    );
    this.off += len;
    return dataHexString;
  }

  readFixedBytes(len: number): string {
    if (this.off + len > this.buf.length) {
      throw Error("out of bound");
    }
    const dataHexString = ethers.utils.hexlify(
      this.buf.slice(this.off, this.off + len)
    );
    this.off += len;
    return dataHexString;
  }

  readBytes(): string {
    return this.readFixedBytes(this.readUint16().toNumber());
  }

  readUint8(): ethers.BigNumber {
    return this.readVarUint(1);
  }

  readUint16(): ethers.BigNumber {
    return this.readVarUint(2);
  }

  readUint32(): ethers.BigNumber {
    return this.readVarUint(4);
  }

  readUint64(): ethers.BigNumber {
    return this.readVarUint(8);
  }

  readUint(): ethers.BigNumber {
    return this.readVarUint(32);
  }

  readBytes1(): string {
    return this.readVarBytes32(1);
  }

  readBytes2(): string {
    return this.readVarBytes32(2);
  }

  readBytes3(): string {
    return this.readVarBytes32(3);
  }

  readBytes4(): string {
    return this.readVarBytes32(4);
  }

  readBytes20(): string {
    return this.readVarBytes32(20);
  }

  readBytes32(): string {
    return this.readVarBytes32(32);
  }

  readAddress(): string {
    return this.readBytes20();
  }

  readBool(): boolean {
    return this.readUint8().toNumber() !== 0;
  }

  readString(): string {
    return ethers.utils.toUtf8String(this.readBytes());
  }

  skip(len: number) {
    if (this.off + len > this.buf.length) {
      throw new Error("len out of bound");
    }
    this.off += len;
  }

  skipBytes(): void {
    this.skip(this.readUint16().toNumber());
  }

  skipString():void{
    this.skipBytes();
  }
}
