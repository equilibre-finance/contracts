import { deploy } from "./deploymentLib";
async function main() {
    const [deployer] = await ethers.getSigners();
    const admin: string = '0x7cef2432A2690168Fb8eb7118A74d5f8EfF9Ef55';
    const vara: string = "0xE1da44C0dA55B075aE8E2e4b6986AdC76Ac77d73";
    const ve: string = "0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A";
    const args = [vara, ve];
    const bVara = await deploy("bVaraImplementation", args);

    /// @dev transfer contract ownership to admin:
    console.log(`Transferring ownership to admin: ${admin}...`);
    await bVara.transferOwnership(admin);
    console.log(`Ownership transferred to admin: ${admin}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

