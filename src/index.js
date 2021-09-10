const ethers = require("ethers");
const dTag = require("../artifacts/contracts/dTag.sol/dTag.json");

const dTagAddress="0x95401dc811bb5740090279Ba06cfA8fcF6113778";

const WriteBuffer = require("./writeBuffer").WriteBuffer;
const ReadBuffer = require("./ReadBuffer").ReadBuffer;

async function testDTag(){
    const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");
    const wallet = new ethers.Wallet("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80", provider);
    const contact = new ethers.Contract(dTagAddress, dTag.abi, provider).connect(wallet);
    const iface = new ethers.utils.Interface(dTag.abi);
    const data = new WriteBuffer().writeString("Hello").writeUint(24).getBytes();
    const dTagTx = await contact.getTagSchema("0xa8a2ae1aaca40523323923d29152812886687dde");
    // const dTagTx = await contact.createTagToUser("0xa8a2ae1aaca40523323923d29152812886687dde", "0xEc929115b0a4A687BAaa81CA760cbF15380F7D0C", data);
    // const dTagTx = await contact.createTagSchema("PersonTag", "name:string;age:uint", "Person Tag", true, 0);
    console.log("dTagTx:",JSON.stringify(dTagTx, undefined ,2));


    await dTagTx.wait();
    const tx = await provider.getTransaction(dTagTx.hash)
    console.log(JSON.stringify(tx, undefined,2));

    const rcp = await provider.getTransactionReceipt(dTagTx.hash);
    console.log("Receipt:", JSON.stringify(rcp, undefined, 2));
    const parseLogs = await iface.parseLog(rcp.logs[0]);
    console.log("ParsedLogs:", JSON.stringify(parseLogs,undefined,2));

    // const tagSchemaId = '0xe2790a5a8a59a65554ab7557317e384cc8331952';
    // const tagSchema = await contact.getTagSchema(tagSchemaId);
    // console.log("TagSchema:", JSON.stringify(tagSchema, undefined, 2));
}

async function  main(){
    await testDTag();
}


void main();
