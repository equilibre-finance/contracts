import {task} from "hardhat/config";

import mainnet_config from "./constants/mainnet-config";
import testnet_config from "./constants/testnet-config";

async function main() {
    const network = await hre.ethers.provider.getNetwork();
    const chainId = network.chainId;
    const mainnet = chainId === 2222;
    console.log(`#Network: ${chainId}`);
    const CONFIG = mainnet ? mainnet_config : testnet_config;
    // Load
    const [ Router2 ] = await Promise.all([
        hre.ethers.getContractFactory("Router2")
    ]);

    const pairFactory = '0x3ca3dA6092C2dd7347638690423f867b8aED1e65';
    const router = await hre.upgrades.deployProxy(Router2, [pairFactory, CONFIG.WETH]);
    await router.deployed();
    console.log('Router2', router.address);
    /*
    try {
        if( chainId === 2222 || chainId === 2221 ) {
            await router.deployTransaction.wait(5);
            await hre.run("verify:verify", {address: router.address, constructorArguments: [pairFactory, CONFIG.WETH]});
        }
    } catch (e) {
        console.log(e.toString());
    }
    */
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

