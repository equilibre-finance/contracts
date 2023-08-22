const BigNumber = require('bignumber.js');
require('dotenv').config()
const merkle = require("@openzeppelin/merkle-tree");
const fs = require("fs");
let airdrop = [], root;

function processFile(file, valueInDecimal) {
    const valueInWei = ethers.utils.parseUnits(valueInDecimal, "ether")
    const addresses = fs.readFileSync(file).toString().split('\n');
    for (let i in addresses) {
        const addr = addresses[i].trim();
        if (!addr) continue;
        airdrop.push(`${addr},${valueInWei}`);
    }
}

function mergeBalances(testAddress, testDecimalAmount) {
    processFile('../airdrop/addr-7days.txt', '450');
    processFile('../airdrop/stake-kava-unique.txt', '420');
    processFile('../airdrop/velo-vest-op.txt', '360');
    processFile('../airdrop/bifi-max-bsc.txt', '360');
    let processed = {}, linesMerkle = [];
    airdrop.push(`${testAddress},${ethers.utils.parseUnits(testDecimalAmount, "ether")}`);
    for (let i in airdrop) {
        const line = airdrop[i].split(',');
        const addr = line[0];
        const currentBalance = new BigNumber(processed[addr] || '0');
        const anotherBalance = new BigNumber(line[1]);
        processed[addr] = currentBalance.plus(anotherBalance).toFixed();
    }
    for (let addr in processed) {
        const balanceInWei = processed[addr];
        linesMerkle.push([addr, balanceInWei]);
    }
    const tree = merkle.StandardMerkleTree.of(linesMerkle, ["address", "uint256"]);
    root = tree.root;
    console.log('Merkle Root:', tree.root);
    return {root: tree.root, tree: tree.dump()};
}

describe("Test", function () {
    describe("default", function () {
        it("all", async function () {
            this.timeout(640000);
            const [DEV] = await ethers.getSigners();
            const wallet = DEV.address.toLowerCase();
            const config = mergeBalances(wallet, "100");
            const Vara = await ethers.getContractFactory("Vara");
            const vara = await Vara.deploy()
            const MerkleClaim = await ethers.getContractFactory("MerkleClaim");

            const main = await MerkleClaim.deploy(vara.address, config.root);
            await vara.setMerkleClaim(main.address);

            const MerkleTreeData = merkle.StandardMerkleTree.load(config.tree);

            console.log(`checking wallet ${wallet}`)
            let proof, amount;
            for (const [i, v] of MerkleTreeData.entries()) {
                if (v[0].toLowerCase() === wallet) {
                    proof = MerkleTreeData.getProof(i);
                    amount = v.splice(",")[1];
                    console.log('Value:', amount);
                    console.log('Proof:', proof);
                }
            }
            if( proof ){
                new Error(`No proof for wallet ${wallet}.`);
            }

            await main.claim(amount, proof);

        });
    });
});
