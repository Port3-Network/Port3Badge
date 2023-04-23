import { expect } from "chai";
import { ethers } from "hardhat";
import { utils, constants, BigNumber, BigNumberish } from 'ethers';
import * as eip712 from './eip712';

import {
  Port3NFTFairBadge,
  Port3NFTFairBadge__factory,
  Port3NFTFairFactory,
  Port3NFTFairFactory__factory,
  Port3NFTFairMultiToken,
  Port3NFTFairMultiToken__factory
} from '../typechain-types';

const { defaultAbiCoder } = utils;
const { AddressZero, HashZero } = constants;

let factory: Port3NFTFairFactory;
let badgeAddr: string;
let multiTokenAddr: string;

// impl
let badgeImpl: string;
let multiTokenImpl: string;

// token data
const badgeName = 'Badge';
const badgeSymbol = 'BAD';
const multiTokenCount = 10;

const fakeUri = 'https://bad.uri/';

enum TokenType {
  ERC721,
  ERC1155
}

describe("Port3NFTFair Test", () => {
  // setup
  before(async() => {
    const admin = (await ethers.getSigners())[0];

    const Badge = (await ethers.getContractFactory('Port3NFTFairBadge')) as Port3NFTFairBadge__factory;
    const badgeContract = await Badge.deploy();
    badgeImpl = badgeContract.address;

    const MultiToken = (await ethers.getContractFactory('Port3NFTFairMultiToken')) as Port3NFTFairMultiToken__factory;
    const multiTokenContract = await MultiToken.deploy();
    multiTokenImpl = multiTokenContract.address;

    const Factory = (await ethers.getContractFactory('Port3NFTFairFactory')) as Port3NFTFairFactory__factory;
    factory = await Factory.deploy(badgeImpl, multiTokenImpl, [admin.address]);
  })

  describe('Port3NFTFairFactory', () => {
    it('should deploy correctly', async() => {
      const getBadgeImpl = await factory.tokenImplementation(TokenType.ERC721);
      const getMultiTokenImpl = await factory.tokenImplementation(TokenType.ERC1155);
      expect(getBadgeImpl).to.eq(badgeImpl);
      expect(getMultiTokenImpl).to.eq(multiTokenImpl);
    })

    it('should deploy Badge', async() => {
      const tx = await factory.deploy721(
        false, // not transferrable by default
        badgeName,
        badgeSymbol,
        fakeUri
      );
      expect(tx).to.emit(factory, 'ProxyCreated');
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'ProxyCreated');
      const args = event?.args;
      badgeAddr = args?.proxy;
    })

    it('should deploy MultiToken', async() => {
      const tx = await factory.deploy1155(
        false, // not transferrable by default
        multiTokenCount,
        fakeUri
      );
      expect(tx).to.emit(factory, 'ProxyCreated');
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'ProxyCreated');
      const args = event?.args;
      multiTokenAddr = args?.proxy;
    })
  })

  describe('Port3NFTFairMultiToken', () => {
    let mint0Id: BigNumberish;
    let mint1Id: BigNumberish;

    it('should deploy correctly', async() => {
      const multiToken = (await ethers.getContractAt('Port3NFTFairMultiToken', multiTokenAddr)) as Port3NFTFairMultiToken;
      const uri = await multiToken.uri(0);
      expect(uri).to.eq(`${fakeUri}0`);
      const tokenCount = await multiToken.tokenIdCount();
      expect(tokenCount.toNumber()).to.eq(multiTokenCount);
      const admin = (await ethers.getSigners())[0].address;
      expect(await multiToken.hasRole(multiToken.DEFAULT_ADMIN_ROLE(), admin)).to.eq(true);
      expect(await multiToken.isTransferrable()).to.be.false;
    })

    it('should assign MINTER_ROLE and MINTING_SIGNER_ROLE', async() => {
      const multiToken = (await ethers.getContractAt('Port3NFTFairMultiToken', multiTokenAddr)) as Port3NFTFairMultiToken;
      const admin = (await ethers.getSigners())[0];
      const minter = (await ethers.getSigners())[1];
      const tx = await multiToken.grantRole(multiToken.MINTER_ROLE(), minter.address);
      expect(tx).to.emit(multiToken, 'RoleGranted');
      expect(await multiToken.hasRole(multiToken.MINTER_ROLE(), minter.address)).to.eq(true);
      expect(await multiToken.hasRole(multiToken.MINTER_ROLE(), admin.address)).to.eq(true);

      const tx1 = await multiToken.grantRole(multiToken.MINTING_SIGNER_ROLE(), minter.address);
      expect(tx1).to.emit(multiToken, 'RoleGranted');
      expect(await multiToken.hasRole(multiToken.MINTING_SIGNER_ROLE(), minter.address)).to.eq(true);

      const rando = (await ethers.getSigners())[2];
      // unauthorized attempt
      const failedTx = multiToken.connect(rando).grantRole(multiToken.MINTER_ROLE(), rando.address);
      await expect(failedTx).to.be.revertedWith(`AccessControl: account ${rando.address.toLowerCase()} is missing role ${HashZero}`);
    })

    it('should safeMint()', async() => {
      const multiToken = (await ethers.getContractAt('Port3NFTFairMultiToken', multiTokenAddr)) as Port3NFTFairMultiToken;
      const minter = (await ethers.getSigners())[1];
      const user = (await ethers.getSigners())[2];
      const randomSeed = Math.floor(Math.random() * 999);
      mint0Id = randomSeed % multiTokenCount;
      const nonce = 0;

      // nonce check
      const expected = await multiToken.isNonceValid(nonce);
      expect(expected).to.be.true;

      await multiToken.connect(minter)["safeMint(address,uint256,uint256)"](user.address, randomSeed, nonce);
      const balance = await multiToken.balanceOf(user.address, mint0Id);
      expect(balance.toNumber()).to.eq(1);
    })

    it('should not re-use nonce to mint tokens', async() => {
      const multiToken = (await ethers.getContractAt('Port3NFTFairMultiToken', multiTokenAddr)) as Port3NFTFairMultiToken;
      const minter = (await ethers.getSigners())[1];
      const user = (await ethers.getSigners())[2];
      const randomSeed = Math.floor(Math.random() * 999);
      const nonce = 0;

      // nonce is no longer available
      const expectedFalse = await multiToken.isNonceValid(nonce);
      expect(expectedFalse).to.be.false;

      const failedTx = multiToken.connect(minter)["safeMint(address,uint256,uint256)"](user.address, randomSeed, nonce);
      await expect(failedTx).to.revertedWith('invalid nonce');
    })

    it('should selfMint()', async() => {
      const multiToken = (await ethers.getContractAt('Port3NFTFairMultiToken', multiTokenAddr)) as Port3NFTFairMultiToken;
      const minter = (await ethers.getSigners())[1];
      const user = (await ethers.getSigners())[2];
      mint1Id = 0;
      let randomSeed = 0;
      while (((await multiToken.balanceOf(user.address, mint1Id)) as BigNumber).gt(0)) {
        randomSeed = Math.floor(Math.random() * 999);
        mint1Id = randomSeed % multiTokenCount;
      }
      const nonce = 1;

      // nonce check
      const expected = await multiToken.isNonceValid(nonce);
      expect(expected).to.be.true;

      // get signature
      const chainId = ethers.provider.network.chainId;
      const signature = await eip712.signMessage(TokenType.ERC1155, minter, chainId, multiTokenAddr, {
        to: user.address,
        randomSeed: randomSeed,
        nonce: nonce
      })

      await multiToken.connect(user)["selfMint(address,uint256,uint256,bytes)"](user.address, randomSeed, nonce, signature);
      const balance = await multiToken.balanceOf(user.address, mint1Id);
      expect(balance.toNumber()).to.eq(1);
    })

    it('should not transfer()', async() => {
      const [, , user, recipient] = await ethers.getSigners();
      const multiToken = (await ethers.getContractAt('Port3NFTFairMultiToken', multiTokenAddr)) as Port3NFTFairMultiToken;

      const failedTx = multiToken.connect(user).safeTransferFrom(user.address, recipient.address, mint0Id, 1, '0x');
      await expect(failedTx).to.be.revertedWith('Port3NFTFairMultiToken: token not transferrable');
    })

    it('should unpause and transfer() tokens', async() => {
      const [owner, , user, recipient] = await ethers.getSigners();
      const multiToken = (await ethers.getContractAt('Port3NFTFairMultiToken', multiTokenAddr)) as Port3NFTFairMultiToken;

      // unpause
      await multiToken.connect(owner).setTransferrable(true);
      expect(await multiToken.isTransferrable()).to.be.true;

      // transfer
      await multiToken.connect(user).safeTransferFrom(user.address, recipient.address, mint0Id, 1, '0x');
      const balance0 = await multiToken.balanceOf(recipient.address, mint0Id);
      expect(balance0).to.eq(1);

      await multiToken.connect(user).safeTransferFrom(user.address, recipient.address, mint1Id, 1, '0x');
      const balance1 = await multiToken.balanceOf(recipient.address, mint1Id);
      expect(balance1).to.eq(1);
    })

    it('should batchMint()', async() => {
      const [, minter, user0, user1, user2] = await ethers.getSigners();
      const multiToken = (await ethers.getContractAt('Port3NFTFairMultiToken', multiTokenAddr)) as Port3NFTFairMultiToken;
      const users = [user0.address, user1.address, user2.address];
      let randomSeeds = [];
      let nonces = [2, 3, 4];

      for (let i = 0; i < 3; i++) {
        let randomSeed = 0;
        let mintId = 0;
        while (((await multiToken.balanceOf(users[i], mintId)) as BigNumber).gt(0)) {
          randomSeed = Math.floor(Math.random() * 999);
          mintId = randomSeed % multiTokenCount;
        }
        randomSeeds.push(randomSeed);
      }

      await multiToken.connect(minter).batchMint(users, randomSeeds, nonces);
    })
  })

  describe('Port3NFTFairBadge', () => {
    it('should deploy correctly', async() => {
      const badge = (await ethers.getContractAt('Port3NFTFairBadge', badgeAddr)) as Port3NFTFairBadge;
      const supply = await badge.totalSupply();
      expect(supply.toNumber()).to.eq(0);
      const name = await badge.name();
      expect(name).to.eq(badgeName);
      const symbol = await badge.symbol();
      expect(symbol).to.eq(badgeSymbol);
      const admin = (await ethers.getSigners())[0].address;
      expect(await badge.hasRole(badge.DEFAULT_ADMIN_ROLE(), admin)).to.eq(true);
      expect(await badge.isTransferrable()).to.be.false;
    })

    it('should assign MINTER_ROLE and MINTING_SIGNER_ROLE', async() => {
      const [admin, minter, signer, user] = await ethers.getSigners();
      const badge = (await ethers.getContractAt('Port3NFTFairBadge', badgeAddr)) as Port3NFTFairBadge;
      
      const tx0 = await badge.grantRole(badge.MINTER_ROLE(), minter.address);
      expect(tx0).to.emit(badge, 'RoleGranted');
      expect(await badge.hasRole(badge.MINTER_ROLE(), minter.address)).to.eq(true);
      expect(await badge.hasRole(badge.MINTER_ROLE(), admin.address)).to.eq(true);

      const tx1 = await badge.grantRole(badge.MINTING_SIGNER_ROLE(), signer.address);
      expect(tx1).to.emit(badge, 'RoleGranted');
      expect(await badge.hasRole(badge.MINTING_SIGNER_ROLE(), signer.address)).to.eq(true);
      expect(await badge.hasRole(badge.MINTING_SIGNER_ROLE(), admin.address)).to.eq(true);

      // unauthorized attempt
      const failedTx = badge.connect(user).grantRole(badge.MINTER_ROLE(), user.address);
      await expect(failedTx).to.be.revertedWith(`AccessControl: account ${user.address.toLowerCase()} is missing role ${HashZero}`);
    })

    it('should safeMint()', async() => {
      const [, minter, , user0, user1] = await ethers.getSigners();
      const badge = (await ethers.getContractAt('Port3NFTFairBadge', badgeAddr)) as Port3NFTFairBadge;

      // safeMint
      await badge.connect(minter)["safeMint(address)"](user0.address);
      const owner0 = await badge.ownerOf(0);
      expect(owner0).to.eq(user0.address);
      expect(await badge.tokenURI(0)).to.eq(fakeUri);
      expect(await badge.totalSupply()).to.eq(1);

      // user should not hold more than one token
      const failedTx = badge.connect(minter)["safeMint(address)"](user0.address);
      await expect(failedTx).to.be.revertedWith('Port3NFTFairBadge: Balance cannot be greater than 1');

      // safeMint with data
      const data = '0x1234';
      await badge.connect(minter)["safeMint(address,bytes)"](user1.address, data);
      const owner1 = await badge.ownerOf(1);
      expect(owner1).to.eq(user1.address);
      expect(await badge.tokenURI(1)).to.eq(fakeUri);
      expect(await badge.totalSupply()).to.eq(2);
    })

    it('should selfMint(), a.k.a. users are allowed to mint directly with an approved signature', async() => {
      const [, , signer, , , user2] = await ethers.getSigners();
      const badge = (await ethers.getContractAt('Port3NFTFairBadge', badgeAddr)) as Port3NFTFairBadge;

      // generate signature
      const chainId = ethers.provider.network.chainId;
      const signature = await eip712.signMessage(TokenType.ERC721, signer, chainId, badgeAddr, {
        to: user2.address
      })

      await badge.connect(user2)["selfMint(address,bytes)"](user2.address, signature);
      const owner2 = await badge.ownerOf(2);
      expect(owner2).to.eq(user2.address);
      expect(await badge.tokenURI(2)).to.eq(fakeUri);
      expect(await badge.totalSupply()).to.eq(3);
    })

    it('should not transfer()', async() => {
      const [, , , user0, user1, user2, recipient] = await ethers.getSigners();
      const badge = (await ethers.getContractAt('Port3NFTFairBadge', badgeAddr)) as Port3NFTFairBadge;

      const failedTx0 = badge.connect(user0).transferFrom(user0.address, recipient.address, 0);
      await expect(failedTx0).to.be.revertedWith('Port3NFTFairBadge: token not transferrable');
      expect(await badge.ownerOf(0)).to.not.eq(recipient.address);

      const failedTx1 = badge.connect(user1).transferFrom(user1.address, recipient.address, 1);
      await expect(failedTx1).to.be.revertedWith('Port3NFTFairBadge: token not transferrable');
      expect(await badge.ownerOf(1)).to.not.eq(recipient.address);

      const failedTx2 = badge.connect(user2).transferFrom(user2.address, recipient.address, 2);
      await expect(failedTx2).to.be.revertedWith('Port3NFTFairBadge: token not transferrable');
      expect(await badge.ownerOf(2)).to.not.eq(recipient.address);
    })

    it('should unpause transfer()', async() => {
      const [owner, , , user0, user1, user2, recipient] = await ethers.getSigners();
      const badge = (await ethers.getContractAt('Port3NFTFairBadge', badgeAddr)) as Port3NFTFairBadge;

      // unpause
      const tx = await badge.connect(owner).setTransferrable(true);
      expect(tx).to.emit(badge, 'TransferrableSet').withArgs(owner.address, true);
      expect(await badge.isTransferrable()).to.be.true;

      // transfer
      await badge.connect(user0).transferFrom(user0.address, recipient.address, 0);
      expect(await badge.ownerOf(0)).to.eq(recipient.address);

      await badge.connect(user1).transferFrom(user1.address, recipient.address, 1);
      expect(await badge.ownerOf(1)).to.eq(recipient.address);

      await badge.connect(user2).transferFrom(user2.address, recipient.address, 2);
      expect(await badge.ownerOf(2)).to.eq(recipient.address);
    })

    it('should batchMint()', async() => {
      const [, minter, , user0, user1, user2] = await ethers.getSigners();
      const users = [user0.address, user1.address, user2.address];
      const badge = (await ethers.getContractAt('Port3NFTFairBadge', badgeAddr)) as Port3NFTFairBadge;
      for (let i = 3; i < 6; i++) {
        await badge.connect(minter).batchMint(users);
        expect(await badge.ownerOf(i)).to.eq(users[i - 3]);
      }
    })
  })
})