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

const pairFactoryAddress: string = '0xA138FAFc30f6Ec6980aAd22656F2F11C38B56a95';
const votingEscrowAddress: string = '0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A';
const veClaimAllFeesAddress: string = '0x2487E24220A82946163e69f2fE0FA9A36760a8af';

let allPools: number;
let factory: Contracts.PairFactory;
let ve: Contracts.VeClaimAllFees;
let claimer: Contracts.VeClaimAllFees;
let allPairsLength: number, gaugesLength: number, bribesLength: number;

describe("claimByAddress", function () {
    beforeEach(async () => {
        this.timeout(140000);
        [runner] = await hre.ethers.getSigners();
        user = new hre.ethers.Wallet(process.env.PRIVATE_KEY_DEV as string, hre.ethers.provider);
        feeBalanceBefore = await user.getBalance();
        factory = await hre.ethers.getContractAt('PairFactory', pairFactoryAddress, user);
        ve = await hre.ethers.getContractAt('VotingEscrow', votingEscrowAddress, user);
        claimer = await hre.ethers.getContractAt('veClaimAllFees', veClaimAllFeesAddress, user);



        /// deploy a local version of claimer contract for local test:

        const claimerFactory = await hre.ethers.getContractFactory('veClaimAllFees');
        claimer = await claimerFactory.deploy();
        await claimer.deployed();

        await claimer.syncGauges();
        await claimer.syncBribes();

        gaugesLength = parseInt((await claimer.gaugesLength()).toString());
        allPairsLength = parseInt((await claimer.allPairsLength()).toString());
        bribesLength = parseInt((await claimer.bribesLength()).toString());

        expect(gaugesLength).to.be.gt(0);
        expect(allPairsLength).to.be.gt(0);
        expect(bribesLength).to.be.gt(0);

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

        /// check if we have sufficient fee balance:
        expect(ethers.BigNumber.from(await user.getBalance()).gt(ethers.BigNumber.from(toWei('0.1')))).to.be.true;

    });

    it("automation", async () => {

        /// approve claimer to operate on all tokens:
        await ve.connect(user).setApprovalForAll(claimer.address, true);

        /// add user to an auto-claim list to test:
        const autoClaimStatus = await claimer.autoClaimStatus(user.address);
        if (!autoClaimStatus) {
            console.log(`Adding user ${user.address} to auto-claim list`);
            await claimer.addToAutoClaimAddresses(user.address);
        }

        /// get the list of users to auto-claim:
        const autoClaimAddresses = await claimer.getAllUsers();
        expect(autoClaimAddresses.length).to.be.gt(0);

        /// show-runner balance and address:
        console.log(`**Runner address: ${runner.address}`);
        console.log(`**Runner balance: ${fromWei(await runner.getBalance())}`);
        /// process all users:
        console.log(`**Processing ${autoClaimAddresses.length} addresses**\n\n`);
        for (let i = 0; i < autoClaimAddresses.length; i++) {
            await claim(autoClaimAddresses[i]);
        }

    });
});


async function claim(address: string): Promise<string[]> {
    let info: string[] = [];
    const tokensOf = parseInt((await ve.balanceOf(user.address)).toString());
    logger(info, `User ${address} owns ${tokensOf} tokens`);

    const sampleToken = await hre.ethers.getContractAt('ERC20', allTokens[0], user);
    const filters:string[] = [ sampleToken.filters.Transfer() ];

    // @dev get a list of token balance before, so we can know what was collected:
    const balancesBefore: BigNumber[] = await updateBalance(address);
    const bribesLength = parseInt( (await claimer.bribesLength()).toString() );
    const block = await hre.ethers.provider.getBlock("latest");
    const gasLimit = block.gasLimit;
    logger(info, `Reward collecting Info:\n---\n`);
    for (let i = 0; i < tokensOf; i++) {
        const tokenId = (await ve.tokenOfOwnerByIndex(address, i)).toString();
        logger(info, ` - Claim bribes of #${tokenId}`);
        let offset = 0;
        let limit = 100;
        for (let i = offset; i < bribesLength; i++) {
            if(offset >= bribesLength) break;
            const left = bribesLength - offset;
            const estimateGas = BigInt( (await claimer.estimateGas.claim(tokenId, offset, limit)).toString() );
            /// @dev check if estimate gas is less than block gas limit:
            expect(ethers.BigNumber.from(estimateGas).lte(ethers.BigNumber.from(gasLimit))).to.be.true;
            const gasPct = ethers.BigNumber.from(estimateGas).mul(ethers.BigNumber.from(100)).div(ethers.BigNumber.from(gasLimit)).toString();
            logger(info, `   Claiming bribes - gas: ${gasToDecimal(estimateGas)}/${gasToDecimal(gasLimit)} (${gasPct}%) - offset: ${offset}, limit: ${limit}, bribes: ${bribesLength}, left: ${left}`);
            const tx = await claimer.claim(tokenId, offset, limit);
            const receipt = await tx.wait();
            const gasUsed = receipt.gasUsed;
            const hash = receipt.transactionHash;
            /// @dev decode events via ethers:


            const events = await claimer.queryFilter(filters, receipt.blockHash);
            console.log('events', events);

            const msg = `   ${hash} - gasUsed: ${gasToDecimal(gasUsed)}/${gasToDecimal(gasLimit)}`;
            logger(info, msg);
            offset += limit;
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
    const feeBalanceAfter = await user.getBalance();
    const feeUsed = feeBalanceBefore.sub(feeBalanceAfter);
    logger(info, `Reward collecting summary:\n---\n`);
    logger(info, `Wallet: ${address}`);
    logger(info, `Fee balance before: ${fromWei(feeBalanceBefore)}`);
    logger(info, `Fee balance after: ${fromWei(feeBalanceAfter)}`);
    logger(info, `Fee used: ${fromWei(feeUsed)}`);
    logger(info, `Tokens: ${allTokens.length}`);
    logger(info, `Gauges: ${gaugesLength}`);
    logger(info, `Pairs: ${allPairsLength}`);
    logger(info, `Bribes: ${bribesLength}`);

    logger(info, `\nReward collected:`);
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
