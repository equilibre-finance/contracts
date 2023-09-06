import { ethers, upgrades } from "hardhat";
import { getImplementationAddress } from '@openzeppelin/upgrades-core';
import {Contract} from "ethers";
import fs from "fs";
async function deploy(name: string, args: any[], verify: boolean = true) {
    /// @dev show deployer address and balance:
    const [deployer] = await ethers.getSigners();
    const network = await ethers.provider.getNetwork();
    const networkId = network.chainId;
    const networkName = network.name;
    console.log("Deploying contracts with the account:", deployer.address);
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log("Account balance:", ethers.formatEther(balance), "ETH");
    // @dev check if we have sufficient funds:
    const fundsInEther = ethers.formatEther(balance);
    if (parseFloat(fundsInEther) < 1) {
        throw new Error(`Insufficient funds in ${deployer.address}! You have: ${fundsInEther} ETH`);
    }

    const ClaimAllImplementation = await ethers.getContractFactory(name);
    const main = await upgrades.deployProxy(ClaimAllImplementation, args);
    const proxyAddress = await main.getAddress();
    console.log(`${name} deployed to ${proxyAddress} at ${networkName} (${networkId})`);

    /// @dev safe to contract storage:
    const contractInfoFile = `contracts.json`;
    if( ! fs.existsSync(contractInfoFile) ) fs.writeFileSync(contractInfoFile, '{}');
    let contractInfo = fs.readFileSync(contractInfoFile, 'utf8');
    contractInfo = JSON.parse(contractInfo || '{}');
    contractInfo[networkId] = contractInfo[networkId] || {};
    contractInfo[networkId][name] = {proxyAddress};
    fs.writeFileSync(contractInfoFile, JSON.stringify(contractInfo, null, 4));

    try {

        if( networkId != 31337 && networkId != 1337 ){
            if( verify ) {
                /// @dev wait 1 minute for the transaction to be mined:
                console.log("Waiting 1 minute for the transaction to be mined...");
                await new Promise(resolve => setTimeout(resolve, 60000));
                await run("verify:verify", {address: proxyAddress, constructorArguments: args});
            }else{
                console.log(`***${name} verification disabled!`);
            }
        }else{
            console.log(`***${name} verification not supported on ${network.chainId}!`);
        }
        return main;
    } catch (e) {
        console.log(e.toString());
    }
}


async function upgrade(name: string, args: any[], verify: boolean = true) {
    /// @dev create new ethers wallet from env private key:
    const deployer = new ethers.Wallet(process.env.PRIVATE_KEY!, ethers.provider);
    /// @dev show deployer address and balance:
    const network = await ethers.provider.getNetwork();
    const networkId = network.chainId;
    const networkName = network.name;
    console.log("Deploying contracts with the account:", deployer.address);
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log("Account balance:", ethers.formatEther(balance), "ETH");
    // @dev check if we have sufficient funds:
    const fundsInEther = ethers.formatEther(balance);
    if (parseFloat(fundsInEther) < 1) {
        throw new Error(`Insufficient funds in ${deployer.address}! You have: ${fundsInEther} ETH`);
    }

    /// @dev safe to contract storage:
    const contractInfoFile = `contracts.json`;
    if( ! fs.existsSync(contractInfoFile) ) fs.writeFileSync(contractInfoFile, '{}');
    let contractInfo = fs.readFileSync(contractInfoFile, 'utf8');
    contractInfo = JSON.parse(contractInfo || '{}');

    const proxyAddress = contractInfo[networkId][name].proxyAddress;

    try {
        const ClaimAllImplementation = await ethers.getContractFactory(name, deployer);
        await upgrades.upgradeProxy(proxyAddress, ClaimAllImplementation, args);
        console.log(`${name} upgradeProxy ${proxyAddress} at ${networkName} (${networkId})`);
    }catch(e){
        console.log(e.toString());
        return;
    }

    try {

        if( networkId != 31337 && networkId != 1337 ){
            if( verify ) {
                /// @dev wait 1 minute for the transaction to be mined:
                console.log("Waiting 1 minute for the transaction to be mined...");
                await new Promise(resolve => setTimeout(resolve, 60000));
                await run("verify:verify", {address: proxyAddress, constructorArguments: args});
            }else{
                console.log(`***${name} verification disabled!`);
            }
        }else{
            console.log(`***${name} verification not supported on ${network.chainId}!`);
        }
    } catch (e) {
        console.log(e.toString());
    }
}

/// @dev do all exports:
export { deploy, upgrade };