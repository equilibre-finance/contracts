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
    const [ Factory ] = await Promise.all([
        hre.ethers.getContractFactory("EQUILIBRE_MULTICALL")
    ]);

    const main = await Factory.deploy();
    await main.deployed();
    console.log('main', main.address);

    try {
        if( chainId === 2222 || chainId === 2221 ) {
            await main.deployTransaction.wait(5);
            await hre.run("verify:verify", {address: main.address, constructorArguments: []});
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

