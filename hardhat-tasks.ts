
import allContracts from "./contracts.json";
import {task} from "hardhat/config";
import mainet from "./scripts/constants/mainnet-config";
import fs from "fs";

interface IContract {
    Vara: string;
    GaugeFactory: string;
    BribeFactory: string;
    PairFactory: string;
    Router: string;
    Router2: string;
    VaraLibrary: string;
    VeArtProxy: string;
    VotingEscrow: string;
    RewardsDistributor: string;
    Voter: string;
    WrappedExternalBribeFactory: string;
    Minter: string;
    VaraGovernor: string;
    MerkleClaim: string;
    EquilibreTvlOracle: string;
    Equilibre_VE_Api: string;
}

function fromWei(value: string, decimals: number = 18): string {
    return ethers.utils.formatUnits(value, decimals);
}

async function loadCfg() {
    const network = await hre.ethers.provider.getNetwork();
    const chainId = network.chainId;
    // @ts-ignore
    return allContracts[chainId] as IContract;
}

task("route-quote", "getAmountOut")
    .addParam("from", "from asset")
    .addParam("to", "to asset")
    .setAction(async (taskArgs) => {
        const cfg = await loadCfg();
        const fromAddress = taskArgs.from;
        const toAddress = taskArgs.to;
        const Router2 = await ethers.getContractFactory("contracts/Router2.sol:Router2");
        const PairFactory = await ethers.getContractFactory("contracts/factories/PairFactory.sol:PairFactory");
        const Pair = await ethers.getContractFactory("contracts/Pair.sol:Pair");
        const ERC20 = await ethers.getContractFactory("@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20");
        const router = Router2.attach(cfg.Router2);
        const factory = PairFactory.attach(cfg.PairFactory);
        const fromToken = ERC20.attach(fromAddress);
        const fromSymbol = await fromToken.symbol();
        const toToken = ERC20.attach(toAddress);
        const toSymbol = await toToken.symbol();
        /*
        const path = [
            {
                from: fromAddress,
                to: toAddress,
                stable: true
            }
        ];
        */
        const path = [
            {
                "from": "0xeb466342c4d449bc9f53a865d5cb90586f405215",
                "to": "0xdb0e1e86b01c4ad25241b1843e407efc4d615248",
                "stable": true
            },
            {
                "from": "0xdb0e1e86b01c4ad25241b1843e407efc4d615248",
                "to": "0xeb466342c4d449bc9f53a865d5cb90586f405215",
                "stable": true
            },
            {
                "from": "0xeb466342c4d449bc9f53a865d5cb90586f405215",
                "to": "0xfa9343c3897324496a05fc75abed6bac29f8a40f",
                "stable": true
            }
        ];
        for( let i = 0; i < path.length; i++) {
            const from = ERC20.attach(path[i].from);
            const to = ERC20.attach(path[i].to);
            const fromSymbol = await from.symbol();
            const toSymbol = await to.symbol();
            const poolAddress = await factory.getPair(path[i].from, path[i].to, path[i].stable);
            const pool = Pair.attach(poolAddress);
            const poolSymbol = await pool.symbol();
            const fromBalance = await from.balanceOf(poolAddress);
            const fromDecimals = await from.decimals();
            const toBalance = await to.balanceOf(poolAddress);
            const toDecimals = await to.decimals();

            const fromBalanceInDecimal = fromWei(fromBalance, fromDecimals);
            const toBalanceInDecimal = fromWei(toBalance, toDecimals);
            console.log(`path ${i}: ${fromSymbol}=${fromBalanceInDecimal} -> ${toSymbol}=${toBalanceInDecimal} (${poolSymbol})`);
        }
        /*
        const amountIn = ethers.utils.parseUnits("1", 6);
        const amounts = await router.getAmountsOut(amountIn, path);
        console.log(`From ${fromSymbol}: ${fromAddress}`);
        console.log(`To ${toSymbol}: ${toAddress}`);
        for( let i = 0; i < amounts.length; i++) {
            console.log(`amounts ${i}: ${fromWei(amounts[i],6)}`);
        }

         */
    });


task("price", "get oracle price").setAction(async () => {
    const cfg = await loadCfg();
    //console.log('mainet', mainet);
    const Pair = await hre.ethers.getContractFactory("contracts/Pair.sol:Pair")
    const Main = await hre.ethers.getContractFactory("contracts/EquilibreTvlOracle.sol:EquilibreTvlOracle")
    const poolAddress = mainet.VARA_KAVA;
    const main = Main.attach(cfg.EquilibreTvlOracle);
    const pair = Pair.attach(poolAddress);
    const name = await pair.name();
    const price = await main.p_t_coin_usd(poolAddress);
    console.log(`poor contract: ${poolAddress}`);
    console.log(`${name} price: ${fromWei(price)}`);
});

task("ve-api-info", "set vara price pool").setAction(async () => {
    const cfg = await loadCfg();
    const Main = await hre.ethers.getContractFactory("contracts/veApi.sol:Equilibre_VE_Api")
    const main = Main.attach(cfg.Equilibre_VE_Api);
    const info = await main.info();
    /*
    _info[0] = block.timestamp;
    _info[1] = price();
    _info[2] = circulatingSupply();
    _info[3] = outstandingSupply();
    _info[4] = dilutedSupply();
    _info[5] = inNFT();
    _info[6] = inGauges();
    _info[7] = inExcluded();
    _info[8] = veNFT.totalSupply();
    _info[9] = lockRatio();
    _info[10] = liquidity();
    _info[11] = circulatingMarketCap();
    _info[12] = marketCap();
    _info[13] = fdv();
    _info[14] = lockedMarketCap();
     */
    const price = fromWei(info[1]);
    const circulatingSupply = fromWei(info[2]);
    const outstandingSupply = fromWei(info[3]);
    const dilutedSupply = fromWei(info[4]);
    const inNFT = fromWei(info[5]);
    const inGauges = fromWei(info[6]);
    const inExcluded = fromWei(info[7]);
    const veNFTTotalSupply = fromWei(info[8]);
    const lockRatio = fromWei(info[9]);
    const liquidity = fromWei(info[10]);
    const circulatingMarketCap = fromWei(info[11]);
    const marketCap = fromWei(info[12]);
    const fdv = fromWei(info[13]);
    const lockedMarketCap = fromWei(info[14]);
    console.log(`price: ${price}`);
    console.log(`circulatingSupply: ${circulatingSupply}`);
    console.log(`outstandingSupply: ${outstandingSupply}`);
    console.log(`dilutedSupply: ${dilutedSupply}`);
    console.log(`inNFT: ${inNFT}`);
    console.log(`inGauges: ${inGauges}`);
    console.log(`inExcluded: ${inExcluded}`);
    console.log(`veNFTTotalSupply: ${veNFTTotalSupply}`);
    console.log(`lockRatio: ${lockRatio}`);
    console.log(`liquidity: ${liquidity}`);
    console.log(`circulatingMarketCap: ${circulatingMarketCap}`);
    console.log(`marketCap: ${marketCap}`);
    console.log(`fdv: ${fdv}`);
    console.log(`lockedMarketCap: ${lockedMarketCap}`);

});

task("ve-api-setPool2", "set vara price pool").setAction(async () => {
    const cfg = await loadCfg();
    const Main = await hre.ethers.getContractFactory("contracts/veApi.sol:Equilibre_VE_Api")
    const main = Main.attach(cfg.Equilibre_VE_Api);
    const poolAddress = mainet.VARA_KAVA;
    const tx = await main.setPool2(poolAddress);
    tx.wait();
    console.log(`setPool2 to ${poolAddress} tx: ${tx.hash}`);
});

task("bribeInfo", "stats about bribes").setAction(async () => {
    const cfg = await loadCfg();
    const IERC20 = await ethers.getContractFactory("contracts/Vara.sol:Vara")
    const Pair = await ethers.getContractFactory("contracts/Pair.sol:Pair")
    const Main = await ethers.getContractFactory("contracts/Voter.sol:Voter")
    const Gauge = await ethers.getContractFactory("contracts/Gauge.sol:Gauge")
    const ExternalBribe = await ethers.getContractFactory("contracts/ExternalBribe.sol:ExternalBribe")
    const main = Main.attach(cfg.Voter);
    const length = await main.length();
    let lines = [];
    for (let i = 0; i < length; ++i) {
        const poolAddress = await main.pools(i);
        const gaugeAddress = await main.gauges(poolAddress);
        const gauge = await Gauge.attach(gaugeAddress);
        const isAlive = await main.isAlive(gaugeAddress);
        const pool = await Pair.attach(poolAddress);
        const symbol = await pool.symbol();
        const fees = await pool.fees();
        const internal_bribe = await gauge.internal_bribe();
        const external_bribe = await gauge.external_bribe();
        const bribe = await ExternalBribe.attach(external_bribe);
        const rewardsListLength = (await bribe.rewardsListLength()).toString();

        if( isAlive ) {
            console.log(`${i}: ${symbol}`);
        }else{
            console.log(`${i}: ${symbol} [DEAD]`);
        }
        for( let j = 0; j < rewardsListLength; j++ ){
            const reward = await bribe.rewards(j);
            const token = IERC20.attach(reward);
            const symbol = await token.symbol();
            const balanceOfBribe = (await token.balanceOf(internal_bribe)).toString();
            const decimals = (await token.decimals()).toString();
            const amount = ethers.utils.formatUnits(balanceOfBribe, decimals);
            if( balanceOfBribe > 0 )
                console.log(` - ${symbol}: ${amount}`);

        }
    }
});


task("gaugeInfo", "Voter.distributeFees").setAction(async () => {
    const cfg = await loadCfg();
    const Pair = await ethers.getContractFactory("contracts/Pair.sol:Pair")
    const Main = await ethers.getContractFactory("contracts/Voter.sol:Voter")
    const Gauge = await ethers.getContractFactory("contracts/Gauge.sol:Gauge")
    const main = Main.attach(cfg.Voter);
    const length = await main.length();
    let lines = [];
    for (let i = 0; i < length; ++i) {
        const poolAddress = await main.pools(i);
        const gaugeAddress = await main.gauges(poolAddress);
        const gauge = await Gauge.attach(gaugeAddress);
        const isAlive = await main.isAlive(gaugeAddress);
        const pool = await Pair.attach(poolAddress);
        const symbol = await pool.symbol();
        const fees = await pool.fees();
        const internal_bribe = await gauge.internal_bribe();
        const external_bribe = await gauge.external_bribe();
        lines.push('-----------------------------------------------------------')
        if( isAlive ) {
            lines.push(` - ${i}: Gauge: ${gaugeAddress} ${symbol}`);
        }else{
            lines.push(` - ${i}: Gauge: ${gaugeAddress} ${symbol} [DEAD]`);
        }
        lines.push(`     Pool: ${poolAddress}`);
        lines.push(`     Pair Fees: ${fees}`);
        lines.push(`     Internal Bribe: ${internal_bribe}`);
        lines.push(`     External Bribe: ${external_bribe}`);
    }
    const str = lines.join('\n');
    console.log(str);
    fs.writeFileSync('./gaugeInfo.txt', str);
});



task("distro", "Voter.distro").setAction(async () => {
    const cfg = await loadCfg();
    const Main = await hre.ethers.getContractFactory("contracts/Voter.sol:Voter")
    const main = Main.attach(cfg.Voter);
    const tx = await main.distro();
    console.log(`${tx.hash}`);
});

task("updateAll", "Voter.updateAll").setAction(async () => {
    const cfg = await loadCfg();
    const Main = await hre.ethers.getContractFactory("Voter")
    const main = Main.attach(cfg.Voter);
    const tx = await main.updateAll();
    console.log(`${tx.hash}`);
});

task("distributeFees", "Voter.distributeFees").setAction(async () => {
    // const cfg = await loadCfg();
    const Pair = await ethers.getContractFactory("contracts/Pair.sol:Pair")
    const Main = await ethers.getContractFactory("contracts/Voter.sol:Voter")
    //const main = Main.attach(cfg.Voter);
    const main = Main.attach('0xa8B1E1B4333202355785C90fB434964046ef2E64');
    let pools = [], gauges = [];
    const length = await main.length();
    for (let i = 0; i < length; ++i) {
        const pool = await main.pools(i);
        const gauge = await main.gauges(pool);
        const isGauge = await main.isGauge(gauge);
        const isAlive = await main.isAlive(gauge);
        const token = await Pair.attach(pool);
        const symbol = await token.symbol();
        console.log(` - ${i}: ${pool} = ${gauge} isGauge=${isGauge} isLive=${isAlive} ${symbol}`);
        pools.push(pool);
        gauges.push(gauge);
    }
    let tx = await main.distributeFees(gauges);
    console.log(`${tx.hash}`);
});

task("gauges", "Voter.distributeFees").setAction(async () => {
    // const cfg = await loadCfg();
    const Pair = await ethers.getContractFactory("contracts/Pair.sol:Pair")
    const Main = await ethers.getContractFactory("contracts/Voter.sol:Voter")
    //const main = Main.attach(cfg.Voter);
    const main = Main.attach('0x4eB2B9768da9Ea26E3aBe605c9040bC12F236a59');
    let pools = [], gauges = [];
    const length = await main.length();
    for (let i = 0; i < length; ++i) {
        const pool = await main.pools(i);
        const gauge = await main.gauges(pool);
        const isGauge = await main.isGauge(gauge);
        const isAlive = await main.isAlive(gauge);
        const token = await Pair.attach(pool);
        const symbol = await token.symbol();
        console.log(` - ${i}: ${gauge} ${symbol}`);
        pools.push(pool);
        gauges.push(gauge);
    }
});

task("showFees", "showFees").setAction(async () => {
    const cfg = await loadCfg();
    const IERC20 = await ethers.getContractFactory("contracts/Vara.sol:Vara")
    const Main = await ethers.getContractFactory("contracts/Voter.sol:Voter")
    const Gauge = await ethers.getContractFactory("contracts/Gauge.sol:Gauge")
    const InternalBribe = await ethers.getContractFactory("contracts/InternalBribe.sol:InternalBribe")
    const main = Main.attach(cfg.Voter);
    const length = await main.length();
    for (let i = 0; i < length; ++i) {
        const poolAddress = await main.pools(i);
        const gaugeAddress = await main.gauges(poolAddress);
        const gauge = Gauge.attach(gaugeAddress);
        const bribeAddress = await gauge.internal_bribe();

        const bribe = InternalBribe.attach(bribeAddress);
        const rewardsListLength = await bribe.rewardsListLength();
        console.log(`bribe ${i} ${bribeAddress} = ${poolAddress}`);
        for( let j = 0; j < rewardsListLength; j++ ){
            const reward = await bribe.rewards(j);
            const token = IERC20.attach(reward);
            const symbol = await token.symbol();
            const balanceOfBribe = await token.balanceOf(bribeAddress);
            console.log(` - ${j} ${symbol}: ${balanceOfBribe}`);

        }
    }
});

task("batchRewardPerToken", "Gauge.batchRewardPerToken").setAction(async () => {
    const cfg = await loadCfg();
    const Main = await ethers.getContractFactory("Voter")
    const Gauge = await ethers.getContractFactory("Gauge")
    const main = Main.attach(cfg.Voter);
    const length = await main.length();
    for (let i = 0; i < length; ++i) {
        const poolAddress = await main.pools(i);
        const gaugeAddress = await main.gauges(poolAddress);
        const gauge = Gauge.attach(gaugeAddress);
        console.log(`- ${i}: ${poolAddress} = ${gaugeAddress}`);
        const supplyNumCheckpoints = await gauge.supplyNumCheckpoints();
        const earned1 = await gauge.earned(cfg.Vara, process.env.MULTISIG);
        let tx = await gauge.batchRewardPerToken(cfg.Vara, supplyNumCheckpoints);
        const earned2 = await gauge.earned(cfg.Vara, process.env.MULTISIG);
        console.log(`  - maxRuns=${supplyNumCheckpoints}, earned1=${earned1}, earned2=${earned2}`);
        console.log(`  - tx=${tx.hash}`);
    }
});

task("earned", "Gauge.earned").setAction(async () => {
    const cfg = await loadCfg();
    const Main = await ethers.getContractFactory("Voter")
    const Gauge = await ethers.getContractFactory("Gauge")
    const main = Main.attach(cfg.Voter);
    const length = await main.length();
    for (let i = 0; i < length; ++i) {
        const poolAddress = await main.pools(i);
        const gaugeAddress = await main.gauges(poolAddress);
        const gauge = Gauge.attach(gaugeAddress);
        const earned = await gauge.earned(cfg.Vara, process.env.MULTISIG);
        const derivedBalance = await gauge.derivedBalance(process.env.MULTISIG);
        console.log(`- ${i}: gauge: ${gaugeAddress}, earned: ${earned}, balance: ${derivedBalance}`);
    }
});
task("rewardPerToken", "Gauge.rewardPerToken").setAction(async () => {
    const cfg = await loadCfg();
    const Main = await ethers.getContractFactory("Voter")
    const Gauge = await ethers.getContractFactory("Gauge")
    const main = Main.attach(cfg.Voter);
    const length = await main.length();
    for (let i = 0; i < length; ++i) {
        const poolAddress = await main.pools(i);
        const gaugeAddress = await main.gauges(poolAddress);
        const gauge = Gauge.attach(gaugeAddress);
        const rewardsListLength = await gauge.rewardsListLength();
        for (let j = 0; j < rewardsListLength; j++) {
            const rewardAddress = await gauge.rewards(j);
            const rewardPerToken = await gauge.rewardPerToken(rewardAddress);
            console.log(`- ${i}/${j}: gauge: ${gaugeAddress}, reward: ${rewardAddress}, rewardPerToken: ${rewardPerToken}`);
        }
    }
});


task("getFees", "getFees")
    .addParam("id", "id")
    .setAction(async (taskArgs) => {
        const tokenId = taskArgs.id;
        const cfg = await loadCfg();
        const Main = await ethers.getContractFactory("Voter")
        const Gauge = await ethers.getContractFactory("Gauge")
        const InternalBribe = await ethers.getContractFactory("InternalBribe")
        const ExternalBribe = await ethers.getContractFactory("ExternalBribe")
        const main = Main.attach(cfg.Voter);
        const length = await main.length();
        for (let i = 0; i < length; ++i) {
            const poolAddress = await main.pools(i);
            const gaugeAddress = await main.gauges(poolAddress);
            const gauge = Gauge.attach(gaugeAddress);
            const internal_bribe = await gauge.internal_bribe();
            const external_bribe = await gauge.external_bribe();
            const internalBribe = InternalBribe.attach(internal_bribe);
            const externalBribe = ExternalBribe.attach(external_bribe);
            console.log(`${i}: gauge: ${gaugeAddress}, internal: ${internal_bribe}, external: ${external_bribe}`);

            let balanceOf = await internalBribe.balanceOf(tokenId);
            if (balanceOf > 0) {
                let rewardsListLength = await internalBribe.rewardsListLength();
                console.log(` - internalBribe ${rewardsListLength}, balanceOf: ${balanceOf}`);
                let rewards = [];
                for (let j = 0; j < rewardsListLength; j++) {
                    const rewardToken = await internalBribe.rewards(j);
                    const earned = await internalBribe.earned(rewardToken, tokenId);
                    const left = await internalBribe.left(rewardToken);
                    if( earned > 0 )
                        console.log(`  - ${j}: token: ${rewardToken} = ${earned}, left: ${left}`);
                    rewards.push(rewardToken);
                }
            }

            balanceOf = await externalBribe.balanceOf(tokenId);
            if (balanceOf > 0) {
                const rewardsListLength = await externalBribe.rewardsListLength();
                console.log(` - externalBribe ${rewardsListLength}, balanceOf: ${balanceOf}`);
                const rewards = [];
                for (let j = 0; j < rewardsListLength; j++) {
                    const rewardToken = await externalBribe.rewards(j);
                    const earned = await externalBribe.earned(rewardToken, tokenId);
                    const left = await externalBribe.left(rewardToken);
                    if( earned > 0 )
                        console.log(`  - ${j}: token: ${rewardToken} = ${earned}, left: ${left}`);
                    rewards.push(rewardToken);
                }
            }
        }
    });


task("merkleRoot", "MerkleClaim.merkleRoot").setAction(async () => {
    // const cfg = await loadCfg();
    const Main = await ethers.getContractFactory("MerkleClaim")
    const Vara = await ethers.getContractFactory("Vara")
    const main = Main.attach('0x6C54e61E0295b6f22d8F91CEd5ddE712f2061eE0');
    const merkleRoot = await main.merkleRoot();
    const varaAddress = await main.VARA();
    const vara = Vara.attach(varaAddress);
    const merkleClaim = await vara.merkleClaim();
    const minter = await vara.minter();
    console.log(`VARA: ${varaAddress}`);
    console.log(`- Vara.merkleRoot: ${merkleRoot}`);
    console.log(`- Vara.merkleClaim: ${merkleClaim}`);
    console.log(`- Vara.minter: ${minter}`);
});
