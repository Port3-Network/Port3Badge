import { ethers } from 'hardhat';
import * as config from './utils/config';

async function main() {
    const MultiToken = await ethers.getContractFactory('Port3NFTFairMultiToken');
    const multitoken = await MultiToken.deploy();
    console.log(`Port3NFTFairMultiToken impl deployed at ${multitoken.address}`);

    const existingConfig = config.read();
    existingConfig['Port3NFTFairMultiToken'] = {
        address: multitoken.address
    }
    config.write(existingConfig);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});