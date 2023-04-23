import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

interface TypedDomain {
    name: string;
    version: string;
    chainId: number;
    verifyingContract: string;
}

enum TokenType {
    ERC721,
    ERC1155
}

export function getDomain(contractAddress: string, chain_id: number, domain_name: string): TypedDomain {
    return {
        name: domain_name,
        version: '1',
        chainId: chain_id,
        verifyingContract: contractAddress,
    };
}

export const BadgeMintType = {
    Mint: [
        { name: 'to', type: 'address' }
    ],
};

export const MultiTokenMintType = {
    Mint: [
        { name: 'to', type: 'address' },
        { name: 'randomSeed', type: 'uint256' },
        { name: 'nonce', type: 'uint256' }
    ]
}

export async function signMessage(
    nft: TokenType,
    signer: SignerWithAddress,
    chainId: number,
    contractAddress: string,
    message: any
): Promise<string> {
    const domainName = nft === TokenType.ERC721 ? 'Port3NFTFairBadge' : 'Port3NFTFairMultiToken';
    const domain: TypedDomain = {
        name: domainName,
        version: '1',
        chainId: chainId,
        verifyingContract: contractAddress,
    }
    const messageType = nft === TokenType.ERC721 ? BadgeMintType : MultiTokenMintType;
    const signature = await signer._signTypedData(domain, messageType, message);
    return signature;
}