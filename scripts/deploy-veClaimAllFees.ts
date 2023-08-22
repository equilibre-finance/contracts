async function main() {
    /// @dev show deployer address and balance:
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    const balance = await deployer.getBalance();
    console.log("Account balance:", hre.ethers.utils.formatEther(balance), "ETH");

    const veClaimAllFees = await hre.ethers.getContractFactory("veClaimAllFees")
    const main = await veClaimAllFees.deploy();
    await main.deployed();
    console.log('main', main.address);

    await main.syncGauges();
    await main.syncBribes();
    await main.syncRewards();

    await main.deployTransaction.wait(20);
    await hre.run("verify:verify", {address: main.address, constructorArguments: []});



}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

