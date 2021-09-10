import { WriteBuffer } from "./WriteBuffer";

export enum TagFieldType {
  Bool,
  Uint,
  Uint8,
  Uint16,
  Uint32,
  Uint64,
  Int,
  Int8,
  Int16,
  Int32,
  Int64,
  Bytes1,
  Bytes2,
  Bytes3,
  Bytes4,
  Bytes8,
  Bytes20,
  Bytes32,
  Address,
  Bytes,
  String,
}

export class TagSchemaField {
  public constructor(
    private fieldName: string,
    private fieldType: TagFieldType
  ) {}

  public getFieldName(): string {
    return this.fieldName;
  }
  public getFieldType(): TagFieldType {
    return this.fieldType;
  }
}

export class TagSchemaFieldBuilder {
  private fields: TagSchemaField[];
  public constructor() {
    this.fields = [] as TagSchemaField[];
  }

  public put(
    fieldName: string,
    fieldType: TagFieldType
  ): TagSchemaFieldBuilder {
    this.fields.push(new TagSchemaField(fieldName, fieldType));
    return this;
  }

  public build(): string {
    const buf: WriteBuffer = new WriteBuffer();
    buf.writeUint8(this.fields.length);
    this.fields.forEach((field) => {
      buf.writeString(field.getFieldName());
      buf.writeUint8(field.getFieldType());
    });
    return buf.getBytes();
  }
}

export type TagDataBuilder = WriteBuffer;
