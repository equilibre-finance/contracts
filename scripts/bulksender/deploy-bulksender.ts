import {task} from "hardhat/config";

import mainnet_config from "./constants/mainnet-config";
import testnet_config from "./constants/testnet-config";

async function main() {
    const network = await hre.ethers.provider.getNetwork();
    const chainId = network.chainId;
    const mainnet = chainId === 2222;
    console.log(`#Network: ${chainId}`);
    const CONFIG = mainnet ? mainnet_config : testnet_config;
    /*
    const [ BulkSender ] = await Promise.all([
        hre.ethers.getContractFactory("BulkSender")
    ]);

    const main = await BulkSender.deploy();
    await main.deployed();
    console.log('main', main.address);
    */
    try {
        if( chainId === 2222 || chainId === 2221 ) {
            //await main.deployTransaction.wait(20);
            const addr = '0x65e21BF68a90eead2e935D8774A171c189F5e940';
            await hre.run("verify:verify", {address: addr, constructorArguments: []});
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

