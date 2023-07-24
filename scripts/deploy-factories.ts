import {task} from "hardhat/config";

import mainnet_config from "./constants/mainnet-config";
import testnet_config from "./constants/testnet-config";

async function main() {
    const network = await hre.ethers.provider.getNetwork();
    const chainId = network.chainId;
    const mainnet = chainId === 2222;
    console.log(`#Network: ${chainId}`);
    const CONFIG = mainnet ? mainnet_config : testnet_config;
    // Load
    const [ Pair, PairFactory, InternalBribe, ExternalBribe, BribeFactory, Gauge, GaugeFactory ] = await Promise.all([
        hre.ethers.getContractFactory("Pair"),
        hre.ethers.getContractFactory("PairFactory"),
        hre.ethers.getContractFactory("InternalBribe"),
        hre.ethers.getContractFactory("ExternalBribe"),
        hre.ethers.getContractFactory("BribeFactory"),
        hre.ethers.getContractFactory("Gauge"),
        hre.ethers.getContractFactory("GaugeFactory"),
    ]);
    const pair = await Pair.deploy();
    await pair.deployed();
    const pairFactory = await hre.upgrades.deployProxy(PairFactory, [pair.address]);
    await pairFactory.deployed();
    console.log('PairFactory', pairFactory.address);

    const internalBribe = await InternalBribe.deploy();
    await internalBribe.deployed();
    const externalBribe = await ExternalBribe.deploy();
    await externalBribe.deployed();
    const bribeFactory = await hre.upgrades.deployProxy(BribeFactory, [internalBribe.address, externalBribe.address]);
    await bribeFactory.deployed();
    console.log('BribeFactory', bribeFactory.address);

    const gauge = await Gauge.deploy();
    await gauge.deployed();
    const gaugeFactory = await hre.upgrades.deployProxy(GaugeFactory, [gauge.address]);
    await gaugeFactory.deployed();
    console.log('GaugeFactory', gaugeFactory.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

