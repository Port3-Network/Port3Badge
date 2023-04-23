import { ethers } from 'hardhat';
import * as config from './utils/config';

async function main() {
    const Badge = await ethers.getContractFactory('Port3NFTFairBadge');
    const badge = await Badge.deploy();
    console.log(`Port3NFTFairBadge impl deployed at ${badge.address}`);

    const existingConfig = config.read();
    existingConfig['Port3NFTFairBadge'] = {
        address: badge.address
    }
    config.write(existingConfig);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});