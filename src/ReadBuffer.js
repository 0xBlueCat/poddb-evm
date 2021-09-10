const ethers = require("ethers");

class ReadBuffer{
    constructor(dataHexString) {
        const data = ethers.utils.arrayify(dataHexString);
        this.buf = new Uint8Array(new ArrayBuffer(data.length));
        this.buf.set(data);
        this.off = 0;
    }

    readVarUint(len){
        if(len <= 0 || len > 32){
            throw new Error("len out of range (0, 32]")
        }
        if(this.off + len > this.buf.length){
            throw  Error("out of bound");
        }
        const bigNumber =  ethers.BigNumber.from(ethers.utils.hexlify(this.buf.slice(this.off, this.off + len)));
        this.off += len;
        return bigNumber;
    }

    readVarBytes32(len){
        if(len <= 0 || len > 32){
            throw new Error("len out of range (0, 32]")
        }
        if(this.off + len > this.buf.length){
            throw  Error("out of bound");
        }
        const dataHexString =  ethers.utils.hexlify(this.buf.slice(this.off, this.off + len));
        this.off += len;
        return dataHexString;
    }

    readFixedBytes(len){
        if(this.off + len > this.buf.length){
            console.log(this.off, len, this.buf.byteLength)
            throw  Error("out of bound");
        }
        const dataHexString =  ethers.utils.hexlify(this.buf.slice(this.off, this.off + len));
        this.off += len;
        return dataHexString;
    }

    readBytes(){
        return this.readFixedBytes(this.readUint32().toNumber())
    }

    readUint8(){
        return this.readVarUint(1);
    }

    readUint16(){
        return this.readVarUint(2);
    }

    readUint32(){
        return this.readVarUint(4);
    }

    readUint64(){
        return this.readVarUint(8);
    }

    readUint(){
        return this.readVarUint(32);
    }

    readBytes1(){
        return this.readVarBytes32(1);
    }

    readBytes2(){
        return this.readVarBytes32(2);
    }

    readBytes3(){
        return this.readVarBytes32(3);
    }

    readBytes4(){
        return this.readVarBytes32(4);
    }

    readBytes20(){
        return this.readVarBytes32(20);
    }

    readBytes32(){
        return this.readVarBytes32(32);
    }

    readAddress(){
        return this.readBytes20()
    }

    readBool(){
        return this.readUint8().toNumber() !== 0
    }

    readString(){
        return ethers.utils.toUtf8String(this.readBytes());
    }

    forward(len){
        if(this.off + len > this.buf.length){
            throw  new Error("len out of bound");
        }
        this.off += len;
    }
}

module.exports = {
    ReadBuffer
}
