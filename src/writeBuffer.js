const ethers = require("ethers");

class WriteBuffer {
    constructor(size = 256) {
        this.buf = new Uint8Array(new ArrayBuffer(size));
        this.off = 0;
    }

    resize(size){
        if(size < this.buf.byteLength){
            throw Error("new size should larger than current cap when resize")
        }
        let newBuf = new Uint8Array(new ArrayBuffer(size));
        newBuf.set(this.buf);
        this.buf = newBuf;
        return this;
    }

    writeVarUint(dataUint, len){
        if(len <= 0 || len > 32){
            throw new Error("len out of range (0, 32]")
        }
        if(this.buf.byteLength < this.off + len){
            this.resize((this.off+len)*2);
        }
        const data = ethers.utils.arrayify(dataUint);
        if(data.length <= len){
             this.buf.set( ethers.utils.zeroPad(data, len), this.off);
        }else{
            this.buf.set(data.slice(data.length-len), this.off)
        }
        this.off += len;
        return this;
    }

    writeVarBytes32(dataHexString, len){
        if(len <= 0 || len > 32){
            throw new Error("len out of range (0, 32]")
        }
        if(this.buf.byteLength < this.off + len){
            this.resize((this.off+len)*2);
        }
        const data = ethers.utils.arrayify(dataHexString);
        if(data.length >= len){
            this.buf.set(data.slice(0,len), this.off);
        }else{
            const tmp = new Uint8Array(len);
            tmp.set(data);
            this.buf.set(tmp, this.off);
        }
        this.off += len;
        return this
    }

    writeFixedBytes(dataHexString){
        const data = ethers.utils.arrayify(dataHexString);
        if(this.buf.byteLength < this.off + data.length){
            this.resize((this.off+data.length)*2);
        }
        this.buf.set(data,this.off);
        this.off += data.length;
        return this;
    }

    writeBytes(dataHexString){
        const data = ethers.utils.arrayify(dataHexString);
        this.writeUint32(data.byteLength);
        this.writeFixedBytes(dataHexString);
        return this;
    }

    writeBytes1(dataHexString){
        this.writeVarBytes32(dataHexString,1);
        return this;
    }

    writeBytes2(dataHexString){
        this.writeVarBytes32(dataHexString, 2);
        return this;
    }

    writeBytes4(dataHexString){
        this.writeVarBytes32(dataHexString, 4);
        return this;
    }

    writeBytes8(dataHexString){
        this.writeVarBytes32(dataHexString, 8);
        return this;
    }

    writeBytes20(dataHexString){
        this.writeVarBytes32(dataHexString, 20);
    }

    writeBytes32(dataHexString){
        this.writeVarBytes32(dataHexString, 32);
        return this;
    }

    writeUint8(dataUint8){
        this.writeVarUint(dataUint8,1);
        return this;
    }

    writeUint16(dataUint16){
        this.writeVarUint(dataUint16, 2);
        return this;
    }

    writeUint32(dataUint32){
        this.writeVarUint(dataUint32, 4);
        return this;
    }

    writeUint64(dataUint64){
        this.writeVarUint(dataUint64, 8);
        return this;
    }

    writeUint(dataUint){
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

    writeAddress(addressHexString){
        this.writeBytes20(addressHexString);
        return this;
    }

    writeBool(dataBool){
        this.writeUint8(dataBool ? 1:0);
        return this;
    }

    writeString(dataString){
        this.writeBytes(ethers.utils.toUtf8Bytes(dataString));
        return this;
    }

    getBytes(){
        return ethers.utils.hexlify(this.buf.slice(0,this.off));
    }

    length(){
        return this.buf.length;
    }
}

module.exports = {
    WriteBuffer
}
