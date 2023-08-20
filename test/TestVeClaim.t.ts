import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/src/signers";
import {BigNumber, BigNumberish} from "ethers";
const {expect} = require("chai");
const {ethers} = require("hardhat");
const hre = require("hardhat");

function toWei(v: BigNumberish) {
    return ethers.utils.parseUnits(v, 'ether').toString();
}

function fromWei(v: BigNumberish) {
    return ethers.utils.formatUnits(v, 'ether').toString();
}
function gasToDecimal(v: BigNumberish) {
    return ethers.utils.formatUnits(v, 'gwei').toString();
}

let feeBalanceBefore: BigNumber;
let signer: SignerWithAddress;
let allTokens:string[] = [];
let balancesBefore:BigNumber[] = [];

async function updateBalance(){
    balancesBefore = [];
    for (let i = 0; i < allTokens.length; i++) {
        const tokenAddress = allTokens[i].toLowerCase();
        const token = await hre.ethers.getContractAt('ERC20', tokenAddress, signer);
        const balance = await token.balanceOf(signer.address);
        balancesBefore.push(balance);
    }
}
describe("claimByAddress", function () {
    it("claimByAddress", async () => {
        this.timeout(140000);

        signer = new hre.ethers.Wallet(process.env.PRIVATE_KEY_DEV as string, hre.ethers.provider);
        feeBalanceBefore = await signer.getBalance();

        const pairFactoryAddress = '0xA138FAFc30f6Ec6980aAd22656F2F11C38B56a95';
        const veClaimAllFeesAddress = '0xd05ED49C98d4759362EFC05De15017351e191257';
        const votingEscrowAddress = '0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A';

        const factory = await hre.ethers.getContractAt('PairFactory', pairFactoryAddress, signer);
        const ve = await hre.ethers.getContractAt('VotingEscrow', votingEscrowAddress, signer);
        // const claimer = await hre.ethers.getContractAt('veClaimAllFees', veClaimAllFeesAddress, signer);

        const veClaimAllFees = await ethers.getContractFactory("veClaimAllFees");
        const claimer = await veClaimAllFees.deploy();
        await claimer.deployed();


        const allPools = parseInt((await factory.allPairsLength()).toString());
        for (let i = 0; i < allPools; i++) {
            const poolAddress = await factory.allPairs(i);
            const pool = await hre.ethers.getContractAt('Pair', poolAddress, signer);
            const token0 = (await pool.token0()).toLowerCase();
            const token1 = (await pool.token1()).toLowerCase();
            if (allTokens.indexOf(token0) === -1)
                allTokens.push(token0);
            if (allTokens.indexOf(token1) === -1)
                allTokens.push(token1);
        }




        const tokensOf = parseInt( (await ve.connect(signer).balanceOf(signer.address)).toString() );
        expect(tokensOf).to.be.gt(0);

        const block = await hre.ethers.provider.getBlock("latest");
        const gasLimit = block.gasLimit;

        await claimer.syncGauges();
        const gaugesLength = parseInt( (await claimer.gaugesLength()).toString() );
        const allPairsLength = parseInt( (await claimer.allPairsLength()).toString() );
        const bribesLength = parseInt( (await claimer.bribesLength()).toString() );
        expect(gaugesLength).to.be.gt(0);
        expect(allPairsLength).to.be.gt(0);
        expect(bribesLength).to.be.gt(0);

        await updateBalance();

        /// check if we have sufficient fee balance:
        expect(ethers.BigNumber.from(await signer.getBalance()).gt(ethers.BigNumber.from(toWei('0.1')))).to.be.true;

        let allGasUsed = ethers.BigNumber.from(0);
        await ve.connect(signer).setApprovalForAll(claimer.address, true);

        let summaryDebug = [`Reward collecting Info:\n\n---\n\n`];
        for( let i = 0; i < tokensOf; i++ ) {
            const tokenId = (await ve.connect(signer).tokenOfOwnerByIndex(signer.address, i)).toString();

            let estimateGas = ethers.BigNumber.from(0);
            try{
                estimateGas = await claimer.connect(signer).estimateGas.claimAllByTokenId(tokenId);
            }catch(e){

            }
            expect(estimateGas).to.be.gt(0);
            expect(estimateGas).to.be.lte(gasLimit);

            // check lastClaimedIndex index to see if we need to do another round:
            let lastClaimedIndex = parseInt( (await claimer.lastClaimedIndex(tokenId)).toString() );
            while( lastClaimedIndex < bribesLength - 1 ) {
                const tx = await claimer.claimAllByTokenId(tokenId);
                const receipt = await tx.wait();
                const gasUsed = receipt.gasUsed;
                allGasUsed = allGasUsed.add(gasUsed);
                const gasPct = gasUsed.mul(100).div(gasLimit);
                const msg = ` - Claimed reward of TokenId ${tokenId} from ${lastClaimedIndex} to ${bribesLength}, gasUsed: ${gasToDecimal(gasUsed)} ${gasPct.toString()}%`;
                summaryDebug.push(msg);
                console.log(msg);
                lastClaimedIndex = parseInt( (await claimer.lastClaimedIndex(tokenId)).toString() );
            }
        }

        // check all balances after:
        let balancesAfter:BigNumber[] = [];
        for (let i = 0; i < allTokens.length; i++) {
            const tokenAddress = allTokens[i];
            const token = await hre.ethers.getContractAt('ERC20', tokenAddress, signer);
            const balance = await token.balanceOf(signer.address);
            balancesAfter.push(balance);
        }

        // display balance differences:
        let summary = [`Reward collecting summary:\n\n---\n\n`];
            summary.push( `Wallet: ${signer.address}` );
            summary.push( `FeeBalance before: ${ethers.utils.formatUnits(feeBalanceBefore, 18).toString()}` );
            summary.push( `FeeBalance after: ${ethers.utils.formatUnits(await signer.getBalance(), 18).toString()}` );
            summary.push( `Fee used: ${ethers.utils.formatUnits(feeBalanceBefore.sub(await signer.getBalance()), 18).toString()}` );
            summary.push( `Tokens: ${allTokens.length}` );
            summary.push( `Gauges: ${gaugesLength}` );
            summary.push( `Pairs: ${allPairsLength}` );
            summary.push( `Bribes: ${bribesLength}` );
            summary.push( `GasUsed: ${gasToDecimal(allGasUsed)}` );
            summary.push( `Reward collected:` );

        for (let i = 0; i < allTokens.length; i++) {
            const tokenAddress = allTokens[i];
            const token = await hre.ethers.getContractAt('ERC20', tokenAddress, signer);
            const decimals = parseInt((await token.decimals()).toString());
            const symbol = await token.symbol();
            const balanceBefore = balancesBefore[i];
            const balanceAfter = balancesAfter[i];
            const diff = balanceAfter.sub(balanceBefore);
            if( ethers.BigNumber.from(diff).gt(0) )
                summary.push( ` - ${symbol}: ${ethers.utils.formatUnits(diff, decimals).toString()}` );
        }

        console.log(summary.join('\n'));
        summaryDebug.push(`\n\n---\n\n`);
        console.log(summaryDebug.join('\n'));

    });

});

