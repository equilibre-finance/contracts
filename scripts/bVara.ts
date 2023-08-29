async function main() {

    /// @dev show deployer address and balance:
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    const balance = await deployer.getBalance();
    console.log("Account balance:", hre.ethers.utils.formatEther(balance), "KAVA");

    const vara: string = "0xE1da44C0dA55B075aE8E2e4b6986AdC76Ac77d73";
    const ve: string = "0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A";
    const bVara = await hre.ethers.getContractFactory("bVara");
    const bVaraContract = await bVara.deploy(vara, ve);

    await bVaraContract.deployed();

    console.log("bVara deployed to:", bVaraContract.address);
    try {
        const network = await hre.ethers.provider.getNetwork();
        if( network.chainId === 2222 || network.chainId === 2221 ) {
            /// @dev wait 1 minute for the transaction to be mined:
            console.log("Waiting 1 minute for the transaction to be mined...");
            await new Promise(resolve => setTimeout(resolve, 60000));
            await hre.run("verify:verify", {address: bVaraContract.address, constructorArguments: [vara, ve]});
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

