// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IPort3NFTFairMultiToken.sol";

contract Port3NFTFairMultiToken is Initializable, AccessControl, ERC1155Supply, IPort3NFTFairMultiToken {
    using EnumerableSet for EnumerableSet.UintSet;
    using BitMaps for BitMaps.BitMap;
    using Strings for uint256;
    
    EnumerableSet.UintSet private _tokenIds;
    string private _baseUri;
    BitMaps.BitMap private _nonceWords;
    bool public override isTransferrable;

    // keccak256(bytes("MINTER_ROLE"))
    bytes32 public constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
    // keccak256(bytes("MINTING_SIGNER_ROLE"))
    bytes32 public constant MINTING_SIGNER_ROLE = 0x4feb5d9fbecb61847562a2be21e3e3ddb5b20bf5c82e64b81fda40c309b017e9;

    // === EIP 712 ===
    string public constant domainName = "Port3NFTFairMultiToken";
    string public constant version = "1";
    // keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"))
    bytes32 public constant DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    // keccak256(bytes("Mint(address to,uint256 randomSeed,uint256 nonce)"))
    bytes32 public constant MINT_TYPEHASH = 0xe418a5ce824d6a0111f43f8b55f437910a4535c0c80ed4a32ba1f768f36c1576;

    event TransferrableSet(address admin, bool transferrable);

    modifier pausable() {
        require(isTransferrable, "Port3NFTFairMultiToken: token not transferrable");
        _;
    }

    constructor() ERC1155("") {
        _disableInitializers();
    }

    function initialize(
        address _admin, 
        uint256 _tokenIdCount, 
        bool _transferrable,
        address[] memory _minterSet,
        string memory _uri
    ) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(MINTER_ROLE, _admin);
        _setupRole(MINTING_SIGNER_ROLE, _admin);
        for (uint256 i = 0; i < _minterSet.length; i++) {
            _setupRole(MINTER_ROLE, _minterSet[i]);
            _setupRole(MINTING_SIGNER_ROLE, _minterSet[i]);
        }
        _setTransferrable(_transferrable);
        _baseUri = _uri;
        _initTokenIds(_tokenIdCount);
    }

    function tokenIdCount() external view returns (uint256) {
        return _tokenIds.length();
    }

    function uri(uint256 id) public view virtual override returns (string memory) {
        return bytes(_baseUri).length > 0 ? string(abi.encodePacked(_baseUri, id.toString())) : "";
    }

    function isNonceValid(uint256 nonceNum) public view returns (bool) {
        return !_nonceWords.get(nonceNum);
    }

    function safeMint(
        address _to,
        uint256 _randomSeed,
        uint256 _nonce
    ) external override onlyRole(MINTER_ROLE) {
        uint256 tokenId = _getId(_randomSeed);
        _mintWithNonce(_to, tokenId, _nonce, "");
    }

    function safeMint(
        address _to,
        uint256 _randomSeed,
        uint256 _nonce,
        bytes calldata _data
    ) external override onlyRole(MINTER_ROLE) {
        uint256 tokenId = _getId(_randomSeed);
        _mintWithNonce(_to, tokenId, _nonce, _data);
    }

    function selfMint(
        address _to,
        uint256 _randomSeed,
        uint256 _nonce,
        bytes calldata _signature
    ) external override {
        _checkSignature(_to, _randomSeed, _nonce, _signature);
        uint256 tokenId = _getId(_randomSeed);
        _mintWithNonce(_to, tokenId, _nonce, "");
    }

    function selfMint(
        address _to,
        uint256 _randomSeed,
        uint256 _nonce,
        bytes calldata _data,
        bytes calldata _signature
    ) external override {
        _checkSignature(_to, _randomSeed, _nonce, _signature);
        uint256 tokenId = _getId(_randomSeed);
        _mintWithNonce(_to, tokenId, _nonce, _data);
    }

    function batchMint(
        address[] calldata _recipients,
        uint256[] calldata _randomSeeds,
        uint256[] calldata _nonces
    ) external override onlyRole(MINTER_ROLE) {
        require(_recipients.length == _randomSeeds.length, "Port3NFTFairMultiToken: recipients and randomSeeds length mismatch");
        require(_recipients.length == _nonces.length, "Port3NFTFairMultiToken: recipients and nonces length mismatch");
        for (uint256 i = 0; i < _recipients.length; i++) {
            if (isNonceValid(_nonces[i])) {
                uint256 tokenId = _getId(_randomSeeds[i]);
                _mintWithNonce(_recipients[i], tokenId, _nonces[i], "");
            }
        }
    }

    function setTransferrable(bool _isTransferrable) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTransferrable(_isTransferrable);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC1155, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // === INTERNAL FUNCTIONS ===

    function _initTokenIds(uint256 n) private {
        uint256 startId = _tokenIds.length();
        for (uint256 i = 0; i < n; i++) {
            _tokenIds.add(startId + i);
        }
    }

    function _getId(uint256 randomSeed) private view returns (uint256) {
        return randomSeed % _tokenIds.length();
    }

    /**
     * @dev Prevents token burning
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        require(to != address(0), "Invalid to address");
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal override pausable {
        super._safeTransferFrom(from, to, id, amount, data);
    }

    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override pausable {
        super._safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function _mintWithNonce(
        address to,
        uint256 id,
        uint256 nonce,
        bytes memory data
    ) internal {
        assert(_tokenIds.contains(id));
        _updateNonce(nonce);
        _mint(to, id, 1, data);
    }

    // === HELPER FUNCTIONS ===
    function _updateNonce(uint256 nonceNum) private {
        require(isNonceValid(nonceNum), "invalid nonce");
        _nonceWords.set(nonceNum);
    }

    function _setTransferrable(bool _transferrable) private {
        isTransferrable = _transferrable;
        emit TransferrableSet(_msgSender(), _transferrable);
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        bytes32 nameHash = keccak256(bytes(domainName));
        bytes32 versionHash = keccak256(bytes(version));
        return keccak256(abi.encode(DOMAIN_TYPEHASH, nameHash, versionHash, block.chainid, address(this)));
    }

    function _hashTypedDataV4(bytes32 structHash) private view returns (bytes32) {
        return ECDSA.toTypedDataHash(_buildDomainSeparator(), structHash);
    }

    function _getDigest(address _to, uint256 _randomSeed, uint256 _nonce) private view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(MINT_TYPEHASH, _to, _randomSeed, _nonce)));
    }

    function _checkSignature(address to, uint256 randomSeed, uint256 nonce, bytes calldata signature) private view {
        bytes32 digest = _getDigest(to, randomSeed, nonce);
        address signer = ECDSA.recover(digest, signature);
        require(hasRole(MINTING_SIGNER_ROLE, signer), "Port3NFTFairMultiToken: invalid signer");
    }
}