import { ethers, network } from 'hardhat';
import * as config from './utils/config';

import * as dotenv from 'dotenv';
dotenv.config();
const { ATA_ADDRESS_0, ATA_ADDRESS_1 } = process.env;

async function main() {
    const badge = 'Port3NFTFairBadge';
    const multi = 'Port3NFTFairMultiToken';
    const currentConfig = config.read();

    if (!currentConfig[badge] || !currentConfig[multi]) {
        throw new Error(`You must deploy ${badge} and ${multi} first`);
    }

    let adminAddr: Array<string>;
    if (network.name === 'hardhat' || network.name === 'localhost') {
        const admin = (await ethers.getSigners())[0];
        adminAddr = [admin.address];
    } else {
        adminAddr = [ATA_ADDRESS_0!, ATA_ADDRESS_1!];
    }

    const Factory = await ethers.getContractFactory('Port3NFTFairFactory');
    const factory = await Factory.deploy(currentConfig[badge].address, currentConfig[multi].address, adminAddr);
    console.log(`Port3NFTFairFactory deployed at ${factory.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});