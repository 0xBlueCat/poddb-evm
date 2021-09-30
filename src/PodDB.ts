import { WriteBuffer } from "./WriteBuffer";
import { ethers } from "ethers";

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
  Array,
}

export enum AgentType {
  Address,
  Tag,
}

export class TagAgentBuilder {
  public Type: AgentType;
  public Agent: string; //EOA address, contract address or tagSchemaId

  constructor(agentType: AgentType, agent: string) {
    this.Type = agentType;
    this.Agent = new WriteBuffer(20).writeBytes20(agent).getBytes();
  }

  public build(): [AgentType, string] {
    return [this.Type, this.Agent];
  }
}

export const NoTagAgent = new TagAgentBuilder(AgentType.Address, "0x").build();

export type TagObject = [string, string];

export function buildTagObject(
  address: string,
  tokenId?: number | string | ethers.BigNumber
): TagObject {
  const addressStr = new WriteBuffer(20).writeAddress(address).getBytes();
  if (tokenId == undefined) {
    tokenId = 0;
  }
  const tokenIdsStr = new WriteBuffer(20)
    .writeUint(ethers.BigNumber.from(tokenId))
    .getBytes();
  return [addressStr, tokenIdsStr];
}

export interface TagClassField {
  fieldName: string;
  fieldType: TagFieldType;
  isArray?: boolean;
}

export class TagClassFieldBuilder {
  private fields: TagClassField[];
  private fieldNames: string;
  private fieldTypes: string;
  public constructor() {
    this.fields = [] as TagClassField[];
  }

  public put(
    fieldName: string,
    fieldType: TagFieldType,
    isArray: boolean
  ): TagClassFieldBuilder {
    this.fields.push({ fieldName, fieldType, isArray });
    return this;
  }

  public build(): TagClassFieldBuilder {
    const buf: WriteBuffer = new WriteBuffer();
    const fieldNames = [] as string[];
    this.fields.forEach((field) => {
      fieldNames.push(field.fieldName);
      if (field.isArray) {
        buf.writeUint8(TagFieldType.Array);
      }
      buf.writeUint8(field.fieldType);
    });
    this.fieldNames = fieldNames.join(",");
    this.fieldTypes = buf.getBytes();
    return this;
  }

  public getFieldNames(): string {
    return this.fieldNames;
  }

  public getFieldTypes(): string {
    return this.fieldTypes;
  }
}
