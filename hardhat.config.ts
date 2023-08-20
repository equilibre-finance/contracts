import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-preprocessor";
import "hardhat-abi-exporter";
import {resolve} from "path";

import {config as dotenvConfig} from "dotenv";
dotenvConfig({path: resolve(__dirname, "./.env")});

import {HardhatUserConfig, task} from "hardhat/config";

// import "./hardhat-tasks";
task("claimByAddress", "claim all fees", async (args, hre) => {
    // const [signer] = await hre.ethers.getSigners();
    // load signer from PRIVATE_KEY_DEV
    const signer = new hre.ethers.Wallet(process.env.PRIVATE_KEY_DEV as string, hre.ethers.provider);
    console.log('signer', signer.address);
    const veClaimAllFeesAddress = '0xd05ED49C98d4759362EFC05De15017351e191257';
    const VotingEscrowAddress = '0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A';
    const claimer = await hre.ethers.getContractAt('veClaimAllFees', veClaimAllFeesAddress, signer);
    const ve = await hre.ethers.getContractAt('VotingEscrow', VotingEscrowAddress, signer);

    const tokens = parseInt( (await ve.balanceOf(signer.address)).toString() );
    if( tokens === 0 ) {
        return console.log('claimByAddress', signer.address, 'no tokens');
    }

    const approveTx = await ve.connect(signer).setApprovalForAll(veClaimAllFeesAddress, true);
    await approveTx.wait();

    console.log('claimByAddress', signer.address, tokens);

    const blockStart = parseInt(process.env.FORKING_BLOCK_NUMBER as string);
    const tx = await claimer.connect(signer).claimByAddress(signer.address);
    await tx.wait();
    const blockEnd = await hre.ethers.provider.getBlockNumber();
    console.log('tx', tx.hash, blockStart, blockEnd);

    // event ClaimFees(uint tokenId, address bribe, address token, uint amount, string symbol);
    // emit ClaimFees(tokenId, bribe, tokens[i], balanceDiff, token.symbol());
    const rawLogs = await hre.ethers.provider.getLogs({
        fromBlock: blockStart,
        toBlock: blockEnd,
        address: veClaimAllFeesAddress,
        topics: [hre.ethers.utils.id('ClaimFees(uint256,address,address,uint256,string)')]
    });
    console.log('rawLogs', rawLogs.length);



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
    }
};


export default config;
