import hre from "hardhat";

async function main() {
    const address: string = '0x0B36b950aC8F71cAcE4c67B3872183483480dD19';
    const ClaimAllImplementation = await hre.ethers.getContractFactory("ClaimAllImplementation")
    const ClaimAllImplementationContract = await ClaimAllImplementation.attach(address);
    const tx = await ClaimAllImplementationContract.setMaxClaimPerTx(100);
    console.log(tx);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

