// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IPort3NFTFairMultiToken is IERC1155 {

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
     * @dev Mints a new token from a random token ID
     * @param _nonce A random and unique integer assigned to this call
     */
    function safeMint(
        address _to,
        uint256 _randomSeed,
        uint256 _nonce
    ) external;
    
    /**
     * @dev Similar with {{ safeMint }}
     * @param _data: callbdata for onERC1155Received
     */
    function safeMint(
        address _to,
        uint256 _randomSeed,
        uint256 _nonce,
        bytes calldata _data
    ) external;

    /**
     * @dev Users can mint their tokens, but requires a signed message from an authorized relayer
     */
    function selfMint(
        address _to,
        uint256 _randomSeed,
        uint256 _nonce,
        bytes calldata _signature
    ) external;
    
    /**
     * @dev Similar with {{ selfMint }}
     * @param _data: callbdata for onERC1155Received
     */
    function selfMint(
        address _to,
        uint256 _randomSeed,
        uint256 _nonce,
        bytes calldata _data,
        bytes calldata _signature
    ) external;

    /**
     * @notice Does not take additional data, therefore one or more recipients cannot be a contract.
     * @dev Mint multiple tokens to multiple addresses within a single call
     */
    function batchMint(
        address[] calldata _recipients,
        uint256[] calldata _randomSeeds,
        uint256[] calldata _nonces
    ) external;
}