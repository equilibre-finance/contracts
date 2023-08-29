import "@nomiclabs/hardhat-ethers";
//import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-preprocessor";
import "hardhat-abi-exporter";
import "hardhat-tracer";
import {resolve} from "path";

import "@nomicfoundation/hardhat-verify";
import "@openzeppelin/hardhat-upgrades";

import {config as dotenvConfig} from "dotenv";

dotenvConfig({path: resolve(__dirname, "./.env")});

import {HardhatUserConfig, task} from "hardhat/config";

task("genkey", "generate a new private key").setAction(async () => {
    const wallet = hre.ethers.Wallet.createRandom();
    console.log(`ADDRESS=${wallet.address}`);
    console.log(`MNEMONIC=${wallet.mnemonic.phrase}`);
    console.log(`PRIVATE_KEY=${wallet.privateKey}`);
});

/// @dev task to create random private key
task("create-wallet", "Create a wallet")
    .setAction(async (args, hre) => {
        const {ethers} = hre;
        const wallet = ethers.Wallet.createRandom();
        console.log(`Address: ${wallet.address}`);
        console.log(`Private Key: ${wallet.privateKey}`);
    });

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            forking: {
                url: process.env.RPC_MAINNET as string,
                blockNumber: parseInt(process.env.FORKING_BLOCK_NUMBER as string)
            }
        },
        mainnet: {
            url: process.env.RPC_MAINNET as string,
            accounts: [process.env.PRIVATE_KEY!]
        },
        testnet: {
            url: process.env.RPC_TESTNET as string,
            accounts: [process.env.PRIVATE_KEY!]
        }
    },
    solidity: {
        version: "0.8.13",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    etherscan: {
        apiKey: {
            testnet: 'x',
            mainnet: 'x'
        },
        customChains: [
            {
                network: "mainnet",
                chainId: 2222,
                urls: {
                    apiURL: "https://kavascan.com/api",
                    browserURL: "https://kavascan.com"
                }
            },
            { // npx hardhat verify --list-networks
                network: "testnet",
                chainId: 2221,
                urls: {
                    apiURL: "https://explorer.testnet.kava.io/api",
                    browserURL: "https://explorer.testnet.kava.io"
                }
            }
        ]
    },
    mocha: {
        timeout: 100_000_000
    }
};


export default config;
