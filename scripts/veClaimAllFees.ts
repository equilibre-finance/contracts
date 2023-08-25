async function main() {

    /// @dev show deployer address and balance:
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    const balance = await deployer.getBalance();
    console.log("Account balance:", hre.ethers.utils.formatEther(balance), "ETH");

    const veClaimAllFees = await hre.ethers.getContractFactory("veClaimAllFees")
    const veClaimAllFeesAddress: string = '0xf2ae02C8Aa3aCB3e8151bC8114834A5c41BA0DA9';
    const main = await veClaimAllFees.attach(veClaimAllFeesAddress);

    const tokenId: string = '5798';
    try {
        const tx = await main.claimAllByTokenId(tokenId);
        console.log('tx:', tx);
    } catch (error) {
        console.log('error:', error.message);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

