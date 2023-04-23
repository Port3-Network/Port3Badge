// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IPort3NFTFairBadge.sol";

contract Port3NFTFairBadge is Initializable, AccessControl, ERC721, IPort3NFTFairBadge {
    uint256 private _supply;
    string private _baseUri;
    string private _proxiedName;
    string private _proxiedSymbol;
    bool public override isTransferrable;

    // keccak256(bytes("MINTER_ROLE"))
    bytes32 public constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
    // keccak256(bytes("MINTING_SIGNER_ROLE"))
    bytes32 public constant MINTING_SIGNER_ROLE = 0x4feb5d9fbecb61847562a2be21e3e3ddb5b20bf5c82e64b81fda40c309b017e9;

    // === EIP 712 ===
    string public constant domainName = "Port3NFTFairBadge";
    string public constant version = "1";
    // keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"))
    bytes32 public constant DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    // keccak256(bytes("Mint(address to)"))
    bytes32 public constant MINT_TYPEHASH = 0x7bfd33bd144b9589a0b3585d6cb96101c2894c984ab9aac14c2b14d4b49b6ee0;

    event TransferrableSet(address admin, bool transferrable);

    constructor() ERC721("", "") {
        _disableInitializers();
    }

    function initialize(
        address _admin, 
        bool _transferrable, 
        address[] memory _minterSet, 
        string memory _name, 
        string memory _symbol, 
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
        _proxiedName = _name;
        _proxiedSymbol = _symbol;
    }

    modifier onlySigner(address to, bytes calldata signature) {
        bytes32 digest = _getDigest(to);
        address signer = ECDSA.recover(digest, signature);
        require(hasRole(MINTING_SIGNER_ROLE, signer), "Port3NFTFairBadge: invalid signer");
        _;
    }

    modifier pausable() {
        require(isTransferrable, "Port3NFTFairBadge: token not transferrable");
        _;
    }

    function safeMint(address _to) external virtual override onlyRole(MINTER_ROLE) {
        _safeMint(_to, _supply);
    }

    function safeMint(address _to, bytes calldata _data) external virtual override onlyRole(MINTER_ROLE) {
        _safeMint(_to, _supply, _data);
    }

    function selfMint(address _to, bytes calldata _signature) 
        external 
        virtual 
        override
        onlySigner(_to, _signature)
    {
        _safeMint(_to, _supply);
    }

    function selfMint(address _to, bytes calldata _data, bytes calldata _signature) 
        external 
        virtual 
        override
        onlySigner(_to, _signature)
    {
        _safeMint(_to, _supply, _data);
    }

    function batchMint(address[] calldata _recipients) external override onlyRole(MINTER_ROLE) {
        for (uint256 i = 0; i < _recipients.length; i++) {
            if (balanceOf(_recipients[i]) < 1) {
                _safeMint(_recipients[i], _supply);
            }
        }
    }

    function setTransferrable(bool _isTransferrable) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTransferrable(_isTransferrable);
    }

    // === OVERRIDES ===

    /**
     * @dev _transfer() can be paused by setting {{ isTransferrable }} to false
     */
    function _transfer (
        address from,
        address to,
        uint256 tokenId
    ) internal override pausable {
        super._transfer(from, to, tokenId);
    }

    /**
     * @dev All tokens share the same URI
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return _baseUri;
    }

    /**
     * @dev Tokens can only be minted when the user possesses less than one token.
     */
    function _safeMint(address _to, uint256 _tokenId, bytes memory _data) internal virtual override {
        require(balanceOf(_to) < 1, "Port3NFTFairBadge: Balance cannot be greater than 1");
        super._safeMint(_to, _tokenId, _data);
        _supply++;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC721, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

     function name() public view virtual override returns (string memory) {
        if (bytes(_proxiedName).length > 0) {
            return _proxiedName;
        }
        return super.name();
    }

    function symbol() public view virtual override returns (string memory) {
        if (bytes(_proxiedSymbol).length > 0) {
            return _proxiedSymbol;
        }
        return super.symbol();
    }

    function totalSupply() external view override returns (uint256) {
        return _supply;
    }

    // === HELPER FUNCTIONS ===
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

    function _getDigest(address _to) private view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(MINT_TYPEHASH, _to)));
    }
}