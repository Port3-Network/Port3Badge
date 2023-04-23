// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IPort3NFTFairBadge is IERC721 {

    /**
     * @dev determines if tokens in the contract can be transferred to another address
     * @return false - causes the _transfer() method to revert
     */
    function isTransferrable() external view returns (bool);

    /**
     * @dev Pauses/unpauses the _transfer() method
     */
    function setTransferrable(bool _isTransferrable) external;

    /**
     * @dev Get the total supply of tokens minted from the contract
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Token minting requires MINTER_ROLE
     */
    function safeMint(address _to) external;

    /**
     * @dev Similar with {{ safeMint }}
     * @param _data: callbdata for onERC721Received
     */
    function safeMint(address _to, bytes calldata _data) external;

    /**
     * @dev Users can mint their tokens, but requires a signed message from an authorized relayer
     */
    function selfMint(address _to, bytes calldata _signature) external;

    /**
     * @dev Similar with {{ selfMint }}
     * @param _data: callbdata for onERC721Received
     */
    function selfMint(address _to, bytes calldata _data, bytes calldata _signature) external;

    /**
     * @notice Does not take additional data, therefore one or more recipients cannot be a contract.
     * @dev Mint multiple tokens to multiple addresses within a single call
     */
    function batchMint(
        address[] calldata _recipients
    ) external;
}