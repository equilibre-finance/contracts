async function main() {
    const veClaimAllFees = await hre.ethers.getContractFactory("veClaimAllFees")
    const main = await veClaimAllFees.deploy();
    await main.deployed();
    console.log('main', main.address);
    await main.deployTransaction.wait(20);
    await hre.run("verify:verify", {address: main.address, constructorArguments: []});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

