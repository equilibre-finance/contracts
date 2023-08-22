import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/src/users";
import {BigNumber, BigNumberish} from "ethers";
import * as Contracts from "../typechain-types";

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

function logger(array: string[], str: string = '') {
    console.log(str);
    array.push(str);
}

let feeBalanceBefore: BigNumber;

let user: SignerWithAddress;
let runner: SignerWithAddress;

let allTokens: string[] = [];

async function updateBalance(address: string): Promise<BigNumber[]> {
    let balancesBefore: BigNumber[] = [];
    for (let i = 0; i < allTokens.length; i++) {
        const tokenAddress = allTokens[i].toLowerCase();
        const token = await hre.ethers.getContractAt('ERC20', tokenAddress, user);
        const balance = await token.balanceOf(address);
        balancesBefore.push(balance);
    }
    return balancesBefore;
}

const pairFactoryAddress = '0xA138FAFc30f6Ec6980aAd22656F2F11C38B56a95';
const veClaimAllFeesAddress = '0x4a66a158815f021fd9E552658e3a10e72B0D243E';
const votingEscrowAddress = '0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A';
let allPools: number;
let factory: Contracts.PairFactory;
let ve: Contracts.VeClaimAllFees;
let claimer: Contracts.VeClaimAllFees;
let allPairsLength: number, gaugesLength: number, bribesLength: number;
let gasLimit: BigNumber = ethers.BigNumber.from(0);
let avgFeeUsed: BigNumber = ethers.BigNumber.from(0);
let tokensProcessed: number = 0;

async function processAddress(address: string): Promise<string[]> {
    let info: string[] = [];
    logger(info, `\n---\nProcessing address ${address}\n---\n`);
    let allGasUsed = ethers.BigNumber.from(0);
    // check if we have sufficient balance to run on all bribes,
    // based on the average gas used so far:
    if (avgFeeUsed.gt(0) && avgFeeUsed.mul(bribesLength).gt(await user.getBalance())) {
        const weNeed = avgFeeUsed.mul(bribesLength);
        const weHave = await user.getBalance();
        const diff = weNeed.sub(weHave);

        const weNeedEth = ethers.utils.formatUnits(weNeed, 18);
        const weHaveEth = ethers.utils.formatUnits(weHave, 18);
        const diffEth = ethers.utils.formatUnits(diff, 18);

        logger(info, `Not enough balance to process address ${address}, we need ${weNeedEth} ETH, we have ${weHaveEth} ETH, diff ${diffEth} ETH`);
        return info;
    }

    const tokensOf = parseInt((await ve.connect(user).balanceOf(user.address)).toString());
    if (tokensOf === 0) {
        console.log(`No tokens for address ${address}`);
        // check if address is on autoClaimAddresses array and remove it:
        const autoClaimAddresses = await claimer.getAllUsers();
        if (autoClaimAddresses.indexOf(address) !== -1) {
            await claimer.removeFromAutoClaimAddresses(address);
            logger(info, `Removed address ${address} from autoClaimAddresses`);
        }
        return info;
    }

    // get user balance to show reward earned info:
    const balancesBefore: BigNumber[] = await updateBalance(address);

    logger(info, `Reward collecting Info:\n---\n`);
    for (let i = 0; i < tokensOf; i++) {
        const tokenId = (await ve.tokenOfOwnerByIndex(address, i)).toString();
        let estimateGas = ethers.BigNumber.from(0);
        try {
            estimateGas = await claimer.estimateGas.claimAllByTokenId(tokenId);
        } catch (e) {

        }
        expect(estimateGas).to.be.gt(0);

        // check lastClaimedIndex index to see if we need to do another round:
        let lastClaimedIndex = parseInt((await claimer.lastClaimedIndex(tokenId)).toString());
        logger(info, ` - TokenId ${tokenId} lastClaimedIndex: ${lastClaimedIndex}, gas: ${gasToDecimal(estimateGas)}`);

        while (lastClaimedIndex < bribesLength - 1) {
            const tx = await claimer.claimAllByTokenId(tokenId);
            const receipt = await tx.wait();
            const gasUsed = receipt.gasUsed;
            allGasUsed = allGasUsed.add(gasUsed);
            const gasPct = gasUsed.mul(100).div(gasLimit);
            const msg = ` -- Claimed reward of TokenId ${tokenId} from ${lastClaimedIndex} to ${bribesLength}, gasUsed: ${gasToDecimal(gasUsed)} ${gasPct.toString()}%`;
            logger(info, msg);
            lastClaimedIndex = parseInt((await claimer.lastClaimedIndex(tokenId)).toString());
            // compute avg of gas used so far:
            tokensProcessed++;
            avgFeeUsed = avgFeeUsed.add(gasUsed);
            avgFeeUsed = avgFeeUsed.div(tokensProcessed);
        }
    }

    // check all balances after:
    let balancesAfter: BigNumber[] = [];
    for (let i = 0; i < allTokens.length; i++) {
        const tokenAddress = allTokens[i];
        const token = await hre.ethers.getContractAt('ERC20', tokenAddress, user);
        const balance = await token.balanceOf(address);
        balancesAfter.push(balance);
    }

    // display balance differences:
    logger(info, `Reward collecting summary:\n---\n`);
    logger(info, `Wallet: ${address}`);
    logger(info, `FeeBalance before: ${ethers.utils.formatUnits(feeBalanceBefore, 18).toString()}`);
    logger(info, `FeeBalance after: ${ethers.utils.formatUnits(await user.getBalance(), 18).toString()}`);
    logger(info, `Fee used: ${ethers.utils.formatUnits(feeBalanceBefore.sub(await user.getBalance()), 18).toString()}`);
    logger(info, `Tokens: ${allTokens.length}`);
    logger(info, `Gauges: ${gaugesLength}`);
    logger(info, `Pairs: ${allPairsLength}`);
    logger(info, `Bribes: ${bribesLength}`);
    logger(info, `GasUsed: ${gasToDecimal(allGasUsed)}`);
    logger(info, `Reward collected:`);

    for (let i = 0; i < allTokens.length; i++) {
        const tokenAddress = allTokens[i];
        const token = await hre.ethers.getContractAt('ERC20', tokenAddress, user);
        const decimals = parseInt((await token.decimals()).toString());
        const symbol = await token.symbol();
        const balanceBefore = balancesBefore[i];
        const balanceAfter = balancesAfter[i];
        const diff = balanceAfter.sub(balanceBefore);
        if (ethers.BigNumber.from(diff).gt(0))
            logger(info, ` - ${symbol}: ${ethers.utils.formatUnits(diff, decimals).toString()}`);
    }

    return info;
}

describe("claimByAddress", function () {
    beforeEach(async () => {
        this.timeout(140000);
        [runner] = await hre.ethers.getSigners();
        user = new hre.ethers.Wallet(process.env.PRIVATE_KEY_DEV as string, hre.ethers.provider);
        feeBalanceBefore = await user.getBalance();
        factory = await hre.ethers.getContractAt('PairFactory', pairFactoryAddress, user);
        ve = await hre.ethers.getContractAt('VotingEscrow', votingEscrowAddress, user);
        claimer = await hre.ethers.getContractAt('veClaimAllFees', veClaimAllFeesAddress, user);
        allPools = parseInt((await factory.allPairsLength()).toString());
        for (let i = 0; i < allPools; i++) {
            const poolAddress = await factory.allPairs(i);
            const pool = await hre.ethers.getContractAt('Pair', poolAddress, user);
            const token0 = (await pool.token0()).toLowerCase();
            const token1 = (await pool.token1()).toLowerCase();
            if (allTokens.indexOf(token0) === -1)
                allTokens.push(token0);
            if (allTokens.indexOf(token1) === -1)
                allTokens.push(token1);
        }

        const block = await hre.ethers.provider.getBlock("latest");
        gasLimit = block.gasLimit;

        // call syncGauges:
        const needToSyncGauges = await claimer.needToSyncGauges();
        if (needToSyncGauges){
            await claimer.syncGauges();
            await claimer.syncBribes();
            await claimer.syncRewards();
        }

        gaugesLength = parseInt((await claimer.gaugesLength()).toString());
        allPairsLength = parseInt((await claimer.allPairsLength()).toString());
        bribesLength = parseInt((await claimer.bribesLength()).toString());

        expect(gaugesLength).to.be.gt(0);
        expect(allPairsLength).to.be.gt(0);
        expect(bribesLength).to.be.gt(0);


        /// check if we have sufficient fee balance:
        expect(ethers.BigNumber.from(await user.getBalance()).gt(ethers.BigNumber.from(toWei('0.1')))).to.be.true;

    });

    it("automation", async () => {

        /// approve claimer to operate on all tokens:
        await ve.connect(user).setApprovalForAll(claimer.address, true);

        /// add user to auto-claim list to test:
        await claimer.addToAutoClaimAddresses(user.address);

        /// get the list of users to auto-claim:
        const autoClaimAddresses = await claimer.getAllUsers();
        expect(autoClaimAddresses.length).to.be.gt(0);

        /// show runner balance and address:
        console.log(`**Runner address: ${runner.address}`);
        console.log(`**Runner balance: ${fromWei(await runner.getBalance())}`);
        /// process all users:
        console.log(`**Processing ${autoClaimAddresses.length} addresses**\n\n`);
        for (let i = 0; i < autoClaimAddresses.length; i++) {
            await processAddress( autoClaimAddresses[i] );
        }

    });
});
