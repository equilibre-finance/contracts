import {ethers} from "ethers";

function toWei(n: string | number) {
    return ethers.parseEther(n.toString());
}

const mainnet_config = {
    GITHUB_SOURCE: "https://github.com/equilibre-finance/contracts/blob/dev/contracts/{CONTRACT}.sol#L{LINE}",
    EXPLORER: "https://kavascan.com/",
    usdc: "0xEB466342C4d449BC9f53A865D5Cb90586f405215",
    wbtc: "0x1a35EE4640b0A3B87705B0A4B45D227Ba60Ca2ad",
    teamEOA: "0x7cef2432A2690168Fb8eb7118A74d5f8EfF9Ef55",
    teamTreasure: '0x3a724E0082b0E833670cF762Ea6bd711bcBdFf37',
    teamMultisig: "0x79dE631fFb7291Acdb50d2717AE32D44D5D00732",
    emergencyCouncil: "0x7cef2432A2690168Fb8eb7118A74d5f8EfF9Ef55",
    merkleRoot: "",
    tokenWhitelist: ["0xEB466342C4d449BC9f53A865D5Cb90586f405215", "0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b"],
    WETH: "0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b",
    factoryAddress: "",
    routerAddress: "",
    positionManagerAddress: "",
};

const testnetArgs = {
    GITHUB_SOURCE: "https://github.com/equilibre-finance/contracts/blob/dev/contracts/{CONTRACT}.sol#L{LINE}",
    EXPLORER: "https://testnet.kavascan.com/",
    usdc: "0x43D8814FdFB9B8854422Df13F1c66e34E4fa91fD",
    wbtc: "0x7be89557B43D2A7270437976D98d017B87b0E466",
    teamEOA: "0xB92F34Fd79e637A7c38e0c9F3439f382EF1214fB",
    teamTreasure: '0xB92F34Fd79e637A7c38e0c9F3439f382EF1214fB',
    teamMultisig: "0xB92F34Fd79e637A7c38e0c9F3439f382EF1214fB",
    emergencyCouncil: "0xB92F34Fd79e637A7c38e0c9F3439f382EF1214fB",
    merkleRoot: "",
    tokenWhitelist: [],
    WETH: "0x6C2A54580666D69CF904a82D8180F198C03ece67",
    factoryAddress: "",
    routerAddress: "",
    positionManagerAddress: "",

};

function getDeploymentConfig(isMainnet: boolean): any {
    return isMainnet ? mainnet_config : testnetArgs
}

// define ConfigArgs
type ConfigArgs = {
    GITHUB_SOURCE: string;
    EXPLORER: string;
    usdc: string;
    wbtc: string;
    teamEOA: string;
    teamTreasure: string;
    teamMultisig: string;
    emergencyCouncil: string;
    merkleRoot: string;
    tokenWhitelist: string[];
    WETH: string;
    factoryAddress: string;
    routerAddress: string;
    positionManagerAddress: string;
}

export {toWei, getDeploymentConfig, ConfigArgs};