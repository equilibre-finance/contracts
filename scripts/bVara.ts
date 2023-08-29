const { ethers, upgrades } = require("hardhat");
async function main() {
    const [deployer] = await ethers.getSigners();
    const admin: string = '0x7cef2432A2690168Fb8eb7118A74d5f8EfF9Ef55';
    const vara: string = "0xE1da44C0dA55B075aE8E2e4b6986AdC76Ac77d73";
    const ve: string = "0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A";
    const bVara = await ethers.getContractFactory("bVaraImplementation");
    const network = await ethers.provider.getNetwork();
    // @dev check if we have sufficient funds:
    const balance = await deployer.provider.getBalance(deployer.address);
    const fundsInEther = ethers.formatEther(balance);
    if (parseFloat(fundsInEther) < 1) {
        throw new Error(`Insufficient funds in ${deployer.address}! You have: ${fundsInEther} ETH`);
    }else{
        console.log(`Deployer ${deployer.address} balance is: ${fundsInEther} KAVA, network: ${network.name} (${network.chainId})`);
    }

    /// @dev deploy bVara contract as proxy:
    const args = [vara, ve];
    const bVaraContract = await upgrades.deployProxy(bVara, args);
    await bVaraContract.waitForDeployment();
    const bVaraAddress = await bVaraContract.getAddress();
    console.log("bVara deployed to:", bVaraAddress);

    /// @dev transfer contract ownership to admin:
    console.log(`Transferring ownership to admin: ${admin}...`);
    await bVaraContract.transferOwnership(admin);

    try {
        if( network.chainId != 31337 && network.chainId != 1337 ){
            /// @dev wait 1 minute for the transaction to be mined:
            console.log("Waiting 1 minute for the transaction to be mined...");
            await new Promise(resolve => setTimeout(resolve, 60000));
            await hre.run("verify:verify", {address: bVaraAddress});
        }else{
            console.log(`***Contract verification not supported on ${network.chainId}!`);
        }
    } catch (e) {
        console.log(e.toString());
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

