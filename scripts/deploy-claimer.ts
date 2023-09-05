import hre from "hardhat";

async function main() {
    const votingEscrowAddress: string = '0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A';
    /// @dev show deployer address and balance:
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    const balance = await deployer.getBalance();
    console.log("Account balance:", hre.ethers.utils.formatEther(balance), "ETH");

    const ClaimAllImplementation = await hre.ethers.getContractFactory("ClaimAllImplementation")

    const main = await ClaimAllImplementation.deploy();
    await main.deployed();
    console.log('ClaimAllImplementation', main.address);

    /// @dev load tester signer private key for testing:
    const wallet = new hre.ethers.Wallet(process.env.PRIVATE_KEY_DEV, hre.ethers.provider);
    console.log('tester wallet', wallet.address);

    const ve = await hre.ethers.getContractAt('VotingEscrow', votingEscrowAddress, wallet);
    await ve.setApprovalForAll(main.address, true);
    await main.addToAutoClaimAddresses(wallet.address);

    await main.syncGauges();
    await main.syncBribes();

    console.log('wait 10 blocks to verify...');

    await main.deployTransaction.wait(20);

    await hre.run("verify:verify", {address: main.address, constructorArguments: []});


}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

