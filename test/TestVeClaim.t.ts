import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/src/users";
import * as Contracts from "../typechain-types";
import {Contract} from "@ethersproject/contracts/src.ts";
import {Result} from "@ethersproject/abi";
import moment from "moment";

const {expect} = require("chai");
const {ethers} = require("hardhat");
const hre = require("hardhat");
import colors from "colors";

const {ZeroAddress} = ethers;
const ERC20: string = 'lib/solmate/src/tokens/ERC20.sol:ERC20';
const week = 86400n * 7n;
let startEpoch = 0n;


const red = (s: string) => console.log(colors.bold.red(s));
const green = (s: string) => console.log(colors.green(s));
const yellow = (s: string) => console.log(colors.yellow(s));
const gray = (s: string) => console.log(colors.gray(s));
const blue = (s: string) => console.log(colors.blue(s));
const magenta = (s: string) => console.log(colors.magenta(s));
const cyan = (s: string) => console.log(colors.cyan(s));
const BLUE = (s: string) => console.log(colors.bold.bgBrightBlue.brightYellow(s));
const error = (s: string) => console.log(colors.bold.bgBrightRed.brightYellow(s));
const die = (s: string) => {
    error(s);
    process.exit(1);
};

const bribeStartEpoch = (timestamp: bigint) => timestamp - (timestamp % week);
const getEpochTimestamp = (timestamp: bigint) => {
    const bribeStart = bribeStartEpoch(timestamp);
    const bribeEnd = bribeStart + week;
    return timestamp < bribeEnd ? bribeStart : bribeStart + week;
}

const getEpochNumber = (timestamp: bigint) => {
    const bribeStart = bribeStartEpoch(timestamp);
    const bribeEnd = bribeStart + week;
    const epochTimestamp = timestamp < bribeEnd ? bribeStart : bribeStart + week;
    return parseInt(((epochTimestamp - startEpoch) / week).toString());
}

/// @dev: do a distribution based on the current epoch, advancing to next epoch.
async function distribute() {
    let block = await hre.ethers.provider.getBlock('latest');
    let timestamp = BigInt(block.timestamp);
    let active_period = await minter.active_period();
    const next_period = active_period + week + 1n;
    const secondsToNextPeriod = parseInt((next_period - timestamp).toString());
    // console.log(`current period: ${moment.unix(active_period.toString()).format('YYYY-MM-DD HH:mm:ss')}`);
    // console.log(`next period: ${moment.unix(next_period.toString()).format('YYYY-MM-DD HH:mm:ss')}`);
    // console.log(`Time left: ${moment.duration(secondsToNextPeriod, 'seconds').humanize()}`);

    // seconds to next period:

    await hre.ethers.provider.send('evm_increaseTime', [secondsToNextPeriod]);
    await hre.ethers.provider.send('evm_mine');
    const nextBlock = await hre.ethers.provider.getBlock('latest');
    const nextEpoch = getEpoch(nextBlock.timestamp);
    const runAt = moment.unix(nextBlock.timestamp).format('YYYY-MM-DD HH:mm:ss');
    // console.log(`Distribute: run at ${runAt}, epoch is: ${nextEpoch.number} (${nextEpoch.datetime})`);

    /// @dev let's check the period:

    block = await hre.ethers.provider.getBlock('latest');
    timestamp = BigInt(block.timestamp);
    const currentPeriod = await minter.active_period();
    const isCurrentPeriod = timestamp >= currentPeriod;
    // console.log(`Distribute: isCurrentPeriod: ${isCurrentPeriod}, current period:
    // ${moment.unix(currentPeriod.toString()).format('YYYY-MM-DD HH:mm:ss')}`);
    expect(isCurrentPeriod).to.be.true;

    BLUE(`Distribute: in ${runAt} for epoch ${nextEpoch.number} (${nextEpoch.datetime})...`);
    const txInfo = await voter.distro();
    cyan(` tx: ${txInfo.hash}. Done.`);

    /*
    const txUpdatePeriod = await minter.update_period();
    const txInfo = await user.provider.getTransaction(txUpdatePeriod.hash);
    const blockNumber = txInfo.blockNumber;
    // event Mint(address indexed sender, uint weekly, uint circulating_supply, uint circulating_emission);
    const events = await minter.queryFilter('Mint', blockNumber, blockNumber);
    expect(events.length).to.be.gt(0);
    const mintEventInfo = events[0].args;
    const weekly = mintEventInfo.weekly;
    expect(weekly > 0n).to.be.true;
    //blue(`Distribute: in ${runAt} for epoch ${nextEpoch.number} (${nextEpoch.datetime}), Mint weekly:
    // ${currency(weekly)}`);
    */

    /*
    /// @display transfer events:
    const transferEvents = await govToken.queryFilter('Transfer', blockNumber, blockNumber);
    expect(transferEvents.length).to.be.gt(0);
    console.log(`Minter: ${minter.target}`);
    for(let i=0; i<transferEvents.length; i++) {
        const event = transferEvents[i];
        const args = event.args;
        const from = args.from;
        const to = args.to;
        const value = args.value;
        const str = `   - Transfer: ${from} -> ${to} : ${currency(value)}`;
        gray(str);
    }
    */
    /*
        // voter: event NotifyReward(address indexed sender, address indexed reward, uint amount);
        const notifyRewardEvents = await voter.queryFilter('NotifyReward', blockNumber, blockNumber);
        expect(notifyRewardEvents.length).to.be.gt(0);

        const reward = notifyRewardEvents[0].args.reward;
        const amount = notifyRewardEvents[0].args.amount;
        const totalWeight = await voter.totalWeight();
        const ratio = amount * BigInt(10 ** 18) / totalWeight;
        const ratioIsValid = ratio > 0n;
        expect(ratioIsValid).to.be.true;
        //green(`   - NotifyReward: ${reward} : ${currency(amount)}`);
        expect(gauges).to.not.be.undefined;
        expect(gauges.length).to.be.gt(0);
    */


    /*
    for (let i = 0; i < gauges.length; i++) {
        const gaugeAddress = gauges[i];

        const isAlive = await voter.isAlive(gaugeAddress);
        if (!isAlive) continue;

        const info = poolInfoByAddress[poolForGauge[gaugeAddress]];
        const symbol = info.symbol;
        await voter.updateGauge(gaugeAddress);
        const claimable = await voter.claimable(gaugeAddress);
        if (claimable === 0n) continue;
        //blue(`   - UpdateGauge: ${gaugeAddress} = ${symbol} : ${currency(claimable)}`);

        const gauge = await hre.ethers.getContractAt('Gauge', gaugeAddress, user);
        const left = await gauge.left(govTokenAddress);
        const leftIsValid1 = claimable > left;
        const leftInEpoch = claimable / week;
        const leftIsValid2 = leftInEpoch > 0n;

        expect(leftIsValid1).to.be.true;
        expect(leftIsValid2).to.be.true;

        //console.log(`   - NotifyReward: ${gaugeAddress} = ${symbol} : ${currency(claimable)}`);

        const callData = voter.interface.encodeFunctionData('distribute(address)', [gaugeAddress]);
        const tx = await user.sendTransaction({to: voter.target, data: callData});
        //const tx = await voter.distribute(gaugeAddress);
        const receipt = await tx.wait();
        const txInfo = await user.provider.getTransaction(receipt.hash);
        const blockNumber = txInfo.blockNumber;
        // event NotifyReward(address indexed from, address indexed reward, uint amount);
        const events = await voter.queryFilter('DistributeReward', blockNumber, blockNumber);
        const event = events[0];
        const args = event.args;
        const amount = args.amount;
        expect(amount > 0n).to.be.true;
        const padRightSymbol = symbol.padEnd(15, ' ');
        const padRightAmount = currency(amount).padStart(10, ' ');
        gray(`   - DistributeReward: ${padRightSymbol} ${padRightAmount}`);
    }

     */
}

const getEpoch = (timestamp: BigNumberish) => {
    timestamp = BigInt(timestamp.toString());
    const ts = getEpochTimestamp(timestamp);
    return {
        number: getEpochNumber(timestamp),
        timestamp: ts,
        datetime: moment.unix(parseInt(ts.toString())).format('YYYY-MM-DD HH:mm:ss'),
        humanized: moment.unix(parseInt(ts.toString())).fromNow()
    };
}

/// @dev convert wei to currency:
const toWei = (v: BigNumberish) => ethers.parseUnits(v, 'ether').toString();
const fromWei = (v: BigNumberish) => ethers.formatUnits(v, 'ether').toString();
const gasToDecimal = (v: BigNumberish) => ethers.formatUnits(v, 'gwei').toString();
const currency = (v: BigNumberish) => parseFloat(fromWei(v)).toFixed(6).replace(/\d(?=(\d{3})+\.)/g, '$&,');
const currency2 = (v: BigNumberish, decimals: number = 18) =>
    parseFloat(ethers.formatUnits(v, decimals).toString()).toFixed(6).replace(/\d(?=(\d{3})+\.)/g, '$&,');

let feeBalanceBefore: bigint;

let user: SignerWithAddress;
let adminAddress: string;
let runner: SignerWithAddress;

const pairFactoryAddress: string = '0xA138FAFc30f6Ec6980aAd22656F2F11C38B56a95';
const votingEscrowAddress: string = '0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A';
const voterAddress: string = '0x4eB2B9768da9Ea26E3aBe605c9040bC12F236a59';
let ClaimAllImplementationAddress: string = '0x2487E24220A82946163e69f2fE0FA9A36760a8af';
const multicallAddress: string = '0xA47a335D1Dcef7039bD11Cbd789aabe3b6Af531f';
const minterAddress: string = '0x46a88F88584c9d4751dB36DA9127F12E4DCAD6B8';
const rewardsDistributorAddress = '0x8825be873e6578F1703628281600d5887C41C55A';
let routerAddress: string = '0xA7544C409d772944017BB95B99484B6E0d7B6388', router: Contracts.Router2;

/// @dev vara address from ve:
let govTokenAddress: string, govToken: Contracts.Vara;
let wEthAddress: string, wEth: Contracts.IWETH;
let rewardsDistributor: Contracts.RewardsDistributor;

let pools: any[], tokens: any[], symbols: any[], decimals: any[], tokensInfo: any;
let poolForGauge: any, poolInfo: [], poolInfoByAddress: any, gauges: any[];
let allBribes: any[], bribesRewards: any;
let gaugeForPool: any;

let factory: Contracts.PairFactory;
let ve: Contracts.VotingEscrow;
let claimer: Contracts.VeClaimAllFees;
let allPairsLength: number;
let Multicall: Contract, voter: Contracts.Voter, minter: Contracts.Minter;

/// @dev set and get cached data from file:
import fs from 'fs';
import path from 'path';
import {BigNumberish} from "ethers";

let cachedData: any = {}, cacheFile: string;

const sudo = async (address: string): Promise<SignerWithAddress> => {
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount", params: [address]
    });
    return await hre.ethers.getSigner(address);
}

/// stop the sudo:
const stopSudo = async (address: string) => {
    await hre.network.provider.request({
        method: "hardhat_stopImpersonatingAccount", params: [address]
    });
}

function set(key: string, value: any) {
    /// @dev create cache file if not exists:
    cachedData[key] = value;
    const str = JSON.stringify(cachedData, (key, value) =>
        typeof value === 'bigint' ? value.toString() : value
    );
    fs.writeFileSync(cacheFile, str);
}

const get = (key: string) => cachedData[key];

async function cacheInit() {

    expect(ZeroAddress).to.be.not.undefined;

    /// @dev construct the cache file name with network and block number:

    const network = await hre.ethers.provider.getNetwork();
    const blockNumber = process.env.FORKING_BLOCK_NUMBER;
    expect(blockNumber).to.be.not.undefined;
    expect(network.name).to.be.not.undefined;
    cacheFile = path.join(__dirname, '..', 'cache', `cache-${network.name}-${blockNumber}.json`);
    // console.log(`Cache file: ${cacheFile}`);
    if (!fs.existsSync(cacheFile))
        fs.writeFileSync(cacheFile, '{}');

    cachedData = JSON.parse(fs.readFileSync(cacheFile).toString());

    allPairsLength = get('allPairsLength');
    gauges = get('gauges');
    gaugeForPool = get('gaugeForPool');
    allBribes = get('allBribes');
    poolInfoByAddress = get('poolInfoByAddress');
    poolInfo = get('poolInfo');
    tokens = get('tokens');
    symbols = get('symbols');
    decimals = get('decimals');
    tokensInfo = get('tokensInfo');
    poolForGauge = get('poolForGauge');
    pools = get('pools');
    bribesRewards = get('bribesRewards');


    /// @dev if any of the cached data is missing, then we need to re-fetch:

    const newPools = parseInt((await factory.allPairsLength()).toString());
    expect(newPools).to.be.gt(0);

    if (allPairsLength === newPools) {
        /// @dev no need to fetch again:
        return;
    }

    console.log('Fetching data from blockchain...');
    allPairsLength = newPools;


    pools = [];
    for (let i = 0; i < newPools; i++) {
        const call = Call(factory, 'allPairs', [i]);
        pools.push(call);
    }
    pools = await multicall(pools);
    pools = pools.map((p: Result) => p[0]);
    expect(pools.length).to.be.gt(0);
    set('pools', pools);
    console.log(`pools: ${pools.length}`);

    /// @dev get all gauges:
    gauges = [];
    for (let i = 0; i < pools.length; i++) {
        const poolAddress = pools[i];
        gauges.push(Call(voter, 'gauges', [poolAddress]));
    }
    gauges = await multicall(gauges);
    gauges = gauges.map((p: Result) => p[0]);
    expect(gauges.length).to.be.gt(0);

    /// @dev get all internal bribes:
    allBribes = [];
    for (let i = 0; i < gauges.length; i++) {
        const gaugeAddress = gauges[i];
        if (gaugeAddress === ZeroAddress) {
            allBribes.push(ZeroAddress);
        } else {
            const gauge = await hre.ethers.getContractAt('Gauge', gaugeAddress, user);
            allBribes.push(Call(gauge, 'internal_bribe', []));
            allBribes.push(Call(gauge, 'external_bribe', []));
        }
    }
    allBribes = await multicall(allBribes);
    allBribes = allBribes.map((p: Result) => p[0]);
    expect(allBribes.length).to.be.gt(0);
    set('allBribes', allBribes);
    console.log(`allBribes: ${allBribes.length}`);

    /// @dev get rewards for internal bribes:
    bribesRewards = {};

    for (let i = 0; i < allBribes.length; i++) {
        const bribeAddress = allBribes[i];
        if (bribeAddress === ZeroAddress) continue;
        const bribe = await hre.ethers.getContractAt('InternalBribe', bribeAddress, user);
        const rewardsListLength = parseInt(await bribe.rewardsListLength());
        let tmpRewards = [];
        for (let j = 0; j < rewardsListLength; j++) {
            tmpRewards.push(Call(bribe, 'rewards', [j]));
        }
        tmpRewards = await multicall(tmpRewards);
        tmpRewards = tmpRewards.map((p: Result) => p[0]);
        tmpRewards = tmpRewards.filter((p: string) => p !== ZeroAddress);
        bribesRewards[bribeAddress] = tmpRewards;
    }
    expect(Object.keys(bribesRewards).length).to.be.gt(0);
    set('bribesRewards', bribesRewards);
    console.log(`bribesRewards: ${Object.keys(bribesRewards).length}`);

    /// @dev set gaugeForPool map:
    gaugeForPool = {};
    for (let i = 0; i < pools.length; i++) {
        gaugeForPool[pools[i]] = gauges[i];
    }
    set('gaugeForPool', gaugeForPool);
    /// @dev filter out zero addresses:
    gauges = gauges.filter((p: string) => p !== ZeroAddress);
    set('gauges', gauges);
    console.log(`gauges: ${gauges.length}, pools: ${pools.length}`);

    tokens = [];
    for (let i = 0; i < pools.length; i++) {
        const poolAddress = pools[i];
        const pool = await hre.ethers.getContractAt('Pair', poolAddress, user);
        tokens.push(Call(pool, 'token0'));
        tokens.push(Call(pool, 'token1'));
    }
    tokens = await multicall(tokens);
    tokens = tokens.map((p: Result) => p[0]);
    /// @dev remove duplicate tokens:
    tokens = [...new Set(tokens)];
    expect(tokens.length).to.be.gt(0);
    set('tokens', tokens);
    console.log(`tokens: ${tokens.length}`);

    symbols = [];
    decimals = [];
    for (let i = 0; i < tokens.length; i++) {
        const tokenAddress = tokens[i];
        const token = await hre.ethers.getContractAt(ERC20, tokenAddress, user);
        symbols.push(Call(token, 'symbol'));
        decimals.push(Call(token, 'decimals'));
    }
    symbols = await multicall(symbols);
    symbols = symbols.map((p: Result) => p[0]);
    set('symbols', symbols);

    decimals = await multicall(decimals);
    decimals = decimals.map((p: Result) => parseInt(p[0].toString()));
    set('decimals', decimals);

    expect(symbols.length).to.be.gt(0);
    expect(decimals.length).to.be.gt(0);

    /// @dev set tokensInfo with symbols and decimals:
    tokensInfo = {};
    for (let i = 0; i < tokens.length; i++) {
        const tokenAddress = tokens[i];
        tokensInfo[tokenAddress] = {
            symbol: symbols[i],
            decimals: decimals[i]
        };
    }
    set('tokensInfo', tokensInfo);


    let tmpPoolForGauge = [];
    for (let i = 0; i < gauges.length; i++) {
        const addr = gauges[i];
        tmpPoolForGauge.push(Call(voter, 'poolForGauge', [addr]));
    }
    tmpPoolForGauge = await multicall(tmpPoolForGauge);
    tmpPoolForGauge = tmpPoolForGauge.map((p: Result) => p[0]);
    expect(tmpPoolForGauge.length).to.be.gt(0);

    poolForGauge = {};
    for (let i = 0; i < gauges.length; i++) {
        const gaugeAddress = gauges[i];
        const poolAddress = tmpPoolForGauge[i];
        poolForGauge[gaugeAddress] = poolAddress;
    }

    set('poolForGauge', poolForGauge);
    expect(poolForGauge).to.be.not.undefined;
    expect(Object.keys(poolForGauge).length).to.be.gt(0);

    /// @dev first, get token info via multicall:
    let tokens0 = [], tokens1 = [];
    for (let i = 0; i < pools.length; i++) {
        const poolAddress = pools[i];
        const pool = await hre.ethers.getContractAt('Pair', poolAddress, user);
        tokens0.push(Call(pool, 'token0', []));
        tokens1.push(Call(pool, 'token1', []));
    }

    tokens0 = await multicall(tokens0);
    tokens1 = await multicall(tokens1);

    tokens0 = tokens0.map((p: Result) => p[0]);
    tokens1 = tokens1.map((p: Result) => p[0]);

    /// @dev set the poolInfo with poolForGauge:
    poolInfo = [];
    poolInfoByAddress = {};
    for (let i = 0; i < pools.length; i++) {
        const poolAddress = pools[i];
        const token0 = tokens0[i];
        const token1 = tokens1[i];
        const token0Info = tokensInfo[token0];
        const token1Info = tokensInfo[token1];
        const poolSymbol = `${token0Info.symbol}-${token1Info.symbol}`;
        const poolInfoItem = {
            symbol: poolSymbol,
            poolAddress: poolAddress,
            token0: token0,
            token1: token1,
            token0Symbol: token0Info.symbol,
            token1Symbol: token1Info.symbol,
            token0Decimals: token0Info.decimals,
            token1Decimals: token1Info.decimals,
            poolForGauge: poolForGauge[i]
        };
        poolInfo.push(poolInfoItem);
        poolInfoByAddress[poolAddress] = poolInfoItem;
    }
    set('poolInfo', poolInfo);
    set('poolInfoByAddress', poolInfoByAddress);
    expect(poolInfo.length).to.be.gt(0);

    /// @dev set the final cache control in the end:
    set('allPairsLength', allPairsLength);

}

async function claimBribesOf(address: string): Promise<string[]> {
    let lastBribeSample
    let info: string[] = [];
    const tokensOf = parseInt((await ve.balanceOf(user.address)).toString());
    BLUE(`# ${tokensOf} TOKENS OF ${address}.`);
    expect(tokensOf).to.be.gt(0);

    // @dev get a list of token balance before, so we can know what was collected:
    const totalBalancesBefore: BigInt[] = await updateBalance(address);

    for (let i = 0; i < tokensOf; i++) {

        // @dev get a list of token balance before, so we can know what was collected:
        const balancesBefore: BigInt[] = await updateBalance(address);

        const tokenId = (await ve.tokenOfOwnerByIndex(address, i)).toString();
        BLUE(`# CLAIM FEES OF #${tokenId}...`);

        /// @dev check approval:
        const isApprovedForAll = await ve.isApprovedForAll(address, ClaimAllImplementationAddress);
        const getApproved = await ve.getApproved(tokenId);
        if (!isApprovedForAll && getApproved !== ClaimAllImplementationAddress) {
            red(`   - no approval for #${tokenId}, skipping...`);
            continue;
        }

        let tokensByFees: any = [], bribesToClaim = [];

        for (let j = 0; j < allBribes.length; j++) {
            lastBribeSample = allBribes[j];
            let rewardsOf = bribesRewards[lastBribeSample];
            expect(rewardsOf.length).to.be.gt(0);
            const bribe = await hre.ethers.getContractAt('InternalBribe', lastBribeSample, user);
            let tokensWithReward: any = [];
            rewardsOf.forEach((token: string) => tokensWithReward.push(Call(bribe, 'earned', [token, tokenId])));
            tokensWithReward = await multicall(tokensWithReward);
            tokensWithReward = tokensWithReward.map((p: Result) => p[0]);

            let onlyTokensWithReward: any = [];
            for (let k = 0; k < tokensWithReward.length; k++) {
                const tokenAddress = rewardsOf[k];
                const reward = tokensWithReward[k];
                if (reward > 0n) {
                    onlyTokensWithReward.push(tokenAddress);
                    const tokenInfo = tokensInfo[tokenAddress];
                    const rewardSymbol = tokenInfo.symbol.padEnd(12, ' ');
                    const rewardDecimals = tokenInfo.decimals;
                    const rewardInCurrency = currency2(reward, rewardDecimals).padStart(12, ' ');
                    const msg = `   - ${lastBribeSample} earned: ${rewardSymbol} ${rewardInCurrency} (${reward.toString()})`;
                    gray(msg);
                }
            }
            if (onlyTokensWithReward.length > 0) {
                bribesToClaim.push(lastBribeSample);
                tokensByFees.push(onlyTokensWithReward);
            }
        }

        if (bribesToClaim.length === 0) {
            blue(` - no bribes with rewards for #${tokenId}, skipping...`);
            continue;
        }

        await claimer.claimFees(bribesToClaim, tokensByFees, tokenId);

        // check all balances after:
        let balancesAfter: BigInt[] = await updateBalance(address);
        balanceDiff(balancesBefore, balancesAfter);

    }

    const totalBalancesAfter: BigInt[] = await updateBalance(address);


    // display balance differences:
    const feeBalanceAfter = await hre.ethers.provider.getBalance(user.address);
    const feeUsed = feeBalanceBefore - feeBalanceAfter;
    BLUE(`# PROCESSING SUMMARY:`);
    magenta(` - Wallet: ${address}`);
    magenta(` - Fee balance before: ${fromWei(feeBalanceBefore)}`);
    magenta(` - Fee balance after: ${fromWei(feeBalanceAfter)}`);
    magenta(` - Fee used: ${fromWei(feeUsed)}`);
    magenta(` - tokens: ${tokens.length}`);
    magenta(` - gauges: ${gauges.length}`);
    magenta(` - Pairs checked: ${allPairsLength}`);
    magenta(` - Internal Bribes checked: ${allBribes.length}`);

    BLUE(`# TOTAL REWARD COLLECTED:`);
    balanceDiff(totalBalancesBefore, totalBalancesAfter);

    return info;
}

function balanceDiff(balancesBefore: BigInt[], balancesAfter: BigInt[]) {
    let total = 0;
    for (let i = 0; i < tokens.length; i++) {
        const symbol = symbols[i].padEnd(12, ' ');
        const diff = BigInt(balancesAfter[i].toString()) - BigInt(balancesBefore[i].toString());
        const diffInCurrency = currency2(diff, decimals[i]).padStart(12, ' ');
        if (diff > 0) {
            magenta(` - ${symbol}: ${diffInCurrency}`);
            total++;
        }
    }
    cyan(` = Total: ${total} tokens`);
}

async function updateBalance(address: string): Promise<BigInt[]> {
    let balancesBefore: any = [];
    for (let i = 0; i < tokens.length; i++) {
        const token = await hre.ethers.getContractAt(ERC20, tokens[i], user);
        balancesBefore.push(Call(token, 'balanceOf', [address]));
    }
    balancesBefore = await multicall(balancesBefore);
    return balancesBefore.map((p: Result) => p[0]);
}

function Call(ctx: Contract, fragment: string, args: any = undefined): {} {
    return {
        ctx: ctx,
        fragment: ctx.interface.getFunction(fragment),
        call: {
            target: ctx.getAddress(),
            callData: ctx.interface.encodeFunctionData(fragment, args),
            fee: 0
        }
    };
}

async function multicall(calls: any[]) {
    expect(calls.length).to.be.gt(0);
    const ctx = calls[0].ctx;
    const fragment = calls[0].fragment;
    expect(ctx).to.be.not.undefined;
    expect(fragment).to.be.not.undefined;
    let results: any[] = [];
    let j = 0;
    const limit = 1000;
    while (j < calls.length) {
        let _calls = [];
        let l = 0;
        for (let i = j; i < j + limit; i++)
            if (calls[i] && calls[i].call) _calls[l++] = calls[i].call;
        const _results = await Multicall.aggregate(_calls);
        results = results.concat(_results[1]);
        j += limit;
    }
    for (let i = 0; i < results.length; i++)
        results[i] = ctx.interface.decodeFunctionResult(fragment, results[i]);
    return results;
}


async function claimRewardsOf(address: string) {
    BLUE(`#Claiming rewards for ${address}`);
    /// @dev loop into gauges and get any earned rewards:
    let earneds: any = [];
    for (let i = 0; i < gauges.length; i++) {
        const gaugeAddress = gauges[i];
        expect(gaugeAddress).to.be.not.undefined;
        expect(gaugeAddress).to.be.not.equal(ZeroAddress);
        const poolForGaugeAddress = poolForGauge[gaugeAddress];
        expect(poolForGaugeAddress).to.be.not.undefined;
        expect(poolForGaugeAddress).to.be.not.equal(ZeroAddress);
        const info = poolInfoByAddress[poolForGaugeAddress];
        expect(info).to.be.not.undefined;
        const gauge = await hre.ethers.getContractAt('Gauge', gaugeAddress, user);
        earneds.push(Call(gauge, 'earned', [govTokenAddress, address]));
    }
    earneds = await multicall(earneds);
    earneds = earneds.map((p: Result) => p[0]);
    let totalEarned = 0n;

    for (let j = 0; j < gauges.length; j++) {
        const earned = earneds[j];
        if (earned === 0n) continue;
        totalEarned += earned;
        const gaugeAddress = gauges[j];
        const poolAddress = poolForGauge[gaugeAddress];
        const info = poolInfoByAddress[poolAddress];
        const amountInCurrency = currency(earned).padStart(12, ' ');
        const symbol = info.symbol.padEnd(15, ' ');
        cyan(`   - earned: ${symbol} ${amountInCurrency} (${earned})`);
    }
    if (totalEarned === 0n) {
        yellow(`   - No rewards to claim for ${address}`);
    } else {
        blue(`   - Claiming ${currency(totalEarned)} rewards for ${address}`);
    }
}

describe("claimByAddress", function () {
    beforeEach(async () => {
        this.timeout(140000);

        const block = await hre.ethers.provider.getBlock("latest");
        const blockTimestamp = block.timestamp;
        const currentTime = new Date().getTime() / 1000;
        const secsDiff = parseInt(blockTimestamp - currentTime);
        /// @dev set the test start epoch to the current block timestamp:
        // console.log(`Current block timestamp: ${blockTimestamp}, secsDiff: ${moment.duration(secsDiff,
        // 'seconds').humanize()}`);
        await hre.ethers.provider.send('evm_increaseTime', [secsDiff]);
        await hre.ethers.provider.send('evm_mine');

        startEpoch = BigInt(process.env.START_BLOCK_TIMESTAMP as string);
        expect(startEpoch).to.be.not.undefined;

        [runner] = await hre.ethers.getSigners();
        user = new hre.ethers.Wallet(process.env.PRIVATE_KEY_DEV as string, hre.ethers.provider);
        feeBalanceBefore = await hre.ethers.provider.getBalance(runner.address);
        factory = await hre.ethers.getContractAt('PairFactory', pairFactoryAddress, runner);
        ve = await hre.ethers.getContractAt('VotingEscrow', votingEscrowAddress, runner);
        Multicall = await hre.ethers.getContractAt('EQUILIBRE_MULTICALL', multicallAddress, runner);
        govTokenAddress = await ve.token();
        govToken = await hre.ethers.getContractAt('Vara', govTokenAddress, runner);
        router = await hre.ethers.getContractAt('Router2', routerAddress, runner);
        wEthAddress = await router.weth();
        wEth = await hre.ethers.getContractAt('IWETH', wEthAddress, runner);
        voter = await hre.ethers.getContractAt('Voter', voterAddress, runner);
        minter = await hre.ethers.getContractAt('Minter', minterAddress, runner);
        adminAddress = await voter.emergencyCouncil();
        rewardsDistributor = await hre.ethers.getContractAt('RewardsDistributor', rewardsDistributorAddress, runner);

        // claimer = await hre.ethers.getContractAt('ClaimAllImplementation', ClaimAllImplementationAddress, user);
        /// deploy a local version of claimer contract for local test:
        const claimerFactory = await hre.ethers.getContractFactory('ClaimAllImplementation');
        claimer = await claimerFactory.deploy();
        ClaimAllImplementationAddress = claimer.target;

        await claimer.syncGauges();
        await claimer.syncBribes();

        /// check if we have sufficient fee balance:
        const balance1 = await hre.ethers.provider.getBalance(runner.address);
        const balance2 = BigInt(toWei('0.1'));
        expect(balance1 > balance2).to.be.true;

        await cacheInit();

    });

    it("automation", async () => {
        await main();


    });
});


/// @dev do some swaps to generate fees:
async function doSwapsAs(_user: SignerWithAddress) {
    const swaps = 10;
    for (let i = 0; i < swaps; i++) {
        const amountIn = toWei('1');
        const tokenIn = wEthAddress;
        let balance = 0n;
        /// @dev check balance:
        if (tokenIn === wEthAddress) {
            balance = await hre.ethers.provider.getBalance(_user.address);
        } else {
            const token = await hre.ethers.getContractAt('ERC20', tokenIn, _user);
            balance = await token.balanceOf(_user.address);
        }
        expect(balance >= amountIn).to.be.true;
        /// @dev do some eth to vara swaps and vara to eth swaps to generate fees:
        await swap(_user, wEthAddress, govTokenAddress, amountIn);
    }
}

/// @dev swap function:
async function swap(_user: SignerWithAddress, tokenIn: string, tokenOut: string, amountIn: bigint) {
    const to = user.address;
    /*
    struct route {
        address from;
        address to;
        bool stable;
    }
     */
    const path: any = [{from: tokenIn, to: tokenOut, stable: false}];

    const getAmountsOut = await router.getAmountsOut(amountIn, path);
    // min amount - less 10%
    let amountOutMin = getAmountsOut[getAmountsOut.length - 1];
    amountOutMin = amountOutMin - (amountOutMin * 10n / 100n);

    const deadline = parseInt((await hre.ethers.provider.getBlock('latest')).timestamp.toString()) + 1000000;

    let tx;
    if (tokenIn === wEthAddress) {
        tx = await router.connect(_user).swapExactETHForTokensSupportingFeeOnTransferTokens(amountOutMin, path, to, deadline, {value: amountIn});
    } else if (tokenOut === wEthAddress) {
        tx = await router.connect(_user).swapExactTokensForETHSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, deadline);
    } else {
        tx = await router.connect(_user).swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, deadline);
    }

    expect(tx).to.be.not.undefined;
    expect(tx.hash).to.be.not.undefined;
    const txInfo = await _user.provider.getTransaction(tx.hash);
    const blockNumber = txInfo.blockNumber;
    // event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out, address
    // indexed to);
    const events = await router.queryFilter('Swap', blockNumber, blockNumber);
    const event = events[0];
    const args = event.args;
    const amount0In = args.amount0In;
    const amount1In = args.amount1In;
    const amount0Out = args.amount0Out;
    const amount1Out = args.amount1Out;
    const amountInDecimal = ethers.utils.formatUnits(amountIn, 'ether');
    const amount0InDecimal = ethers.utils.formatUnits(amount0In, 'ether');
    const amount1InDecimal = ethers.utils.formatUnits(amount1In, 'ether');
    const amount0OutDecimal = ethers.utils.formatUnits(amount0Out, 'ether');
    const amount1OutDecimal = ethers.utils.formatUnits(amount1Out, 'ether');
    const msg = `   - Swap: ${amountInDecimal} ${to} -> ${amount0OutDecimal} ${path[0]} + ${amount1OutDecimal} ${path[1]}`;
    gray(msg);
}

async function claimRewardOf(address: string) {
    const tokensOf = parseInt((await ve.balanceOf(user.address)).toString());
    BLUE(`#CLAIM REWARD: ${tokensOf} TOKENS OF ${address}.`);
    expect(tokensOf).to.be.gt(0);

    let _claimables = [], _balancesBefore = [];
    for (let i = 0; i < tokensOf; i++) {
        const tokenId = (await ve.tokenOfOwnerByIndex(address, i)).toString();
        _claimables.push(await rewardsDistributor.claimable(tokenId));
        _balancesBefore.push(await ve.balanceOfNFT(tokenId));
    }
    await claimer.claimRewards(address);
    for (let i = 0; i < tokensOf; i++) {
        const tokenId = (await ve.tokenOfOwnerByIndex(address, i)).toString();
        const claimable = _claimables[i];
        const balanceBefore = _balancesBefore[i];
        const currentBalance = await ve.balanceOfNFT(tokenId);
        const tokenIdPadded = tokenId.padStart(5, ' ');
        const claimableInCurrency = currency(claimable).padStart(15, ' ');
        const diff = currentBalance - balanceBefore;
        const diffInCurrency = currency(diff).padStart(15, ' ');
        const balanceBeforeInCurrency = currency(balanceBefore).padStart(15, ' ');
        const currentBalanceInCurrency = currency(currentBalance).padStart(15, ' ');
        const msg = `   - #${tokenIdPadded}: ${balanceBeforeInCurrency} -> ${currentBalanceInCurrency} (${claimableInCurrency}/${diffInCurrency})`;
        gray(msg);
    }

}

async function main() {

    /// @dev do some swaps to generate fees:
    //await doSwapsAs(user);

    /// approve claimer to operate on all tokens:
    await ve.connect(user).setApprovalForAll(claimer.target, true);

    /// add user to an auto-claim list to test:
    const autoClaimStatus = await claimer.autoClaimStatus(user.address);
    if (!autoClaimStatus) {
        // console.log(`Adding user ${user.address} to auto-claim list`);
        await claimer.addToAutoClaimAddresses(user.address);
    }

    /// get the list of users to auto-claim:
    const autoClaimAddresses = await claimer.getAllUsers();
    expect(autoClaimAddresses.length).to.be.gt(0);

    /// @dev do a distribution advancing to the next epoch, so we can full test the protocol:
    await distribute();


    /// process all users:
    // console.log(`**Processing ${autoClaimAddresses.length} addresses**\n\n`);
    for (let i = 0; i < autoClaimAddresses.length; i++) {
        await claimBribesOf(autoClaimAddresses[i]);
        // await claimRewardsOf(autoClaimAddresses[i]);
        await claimRewardOf(autoClaimAddresses[i]);
    }
}