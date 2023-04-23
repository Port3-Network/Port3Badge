// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./Port3NFTFairProxy.sol";

contract Port3NFTFairFactory is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    enum TokenType {
        ERC721,
        ERC1155
    }

    EnumerableSet.AddressSet private _ataAddresses;

    mapping (TokenType => address) public tokenImplementation;

    event ImplChanged(TokenType tokenType, address newImplementation);
    event ProxyCreated(address indexed proxy, TokenType tokenType, address deployer);
    event AtaAddrAdded(address[] ata);
    event AtaAddrRemoved(address[] ata);

    constructor(address _erc721Impl, address _erc1155Impl, address[] memory _ata) {
        tokenImplementation[TokenType.ERC721] = _erc721Impl;
        emit ImplChanged(TokenType.ERC721, _erc721Impl);
        
        tokenImplementation[TokenType.ERC1155] = _erc1155Impl;
        emit ImplChanged(TokenType.ERC1155, _erc1155Impl);

        _addAtaMinter(_ata);
    }

    function setImpl(TokenType tokenType, address newImpl) external onlyOwner {
        tokenImplementation[tokenType] = newImpl;
        emit ImplChanged(tokenType, newImpl);
    }

    function addDefaultMinter(address[] memory ata) external onlyOwner {
        _addAtaMinter(ata);
    }

    function removeDefaultMinter(address[] memory ata) external onlyOwner {
        _removeAtaMinter(ata);
    }

    function getDefaultMinterSet() public view returns(address[] memory) {
        return _ataAddresses.values();
    }

    function deploy721(
        bool _transferrable,
        string memory _name, 
        string memory _symbol, 
        string memory _uri
    ) external {
        bytes memory params = abi.encode(msg.sender, _transferrable, getDefaultMinterSet(), _name, _symbol, _uri);
        _deploy(TokenType.ERC721, params);
    }

    function deploy1155(
        bool _transferrable,
        uint256 _tokenIdCount,
        string memory _uri
    ) external {
        bytes memory params = abi.encode(msg.sender, _tokenIdCount, _transferrable, getDefaultMinterSet(), _uri);
        _deploy(TokenType.ERC1155, params);
    }

    function _generateInitData(TokenType token, bytes memory data) private pure returns (bytes memory res) {
        bytes4 selector; // initialize() selector
        if (token == TokenType.ERC1155) {
            selector = 0x0cbc5f88;
        } else {
            selector = 0xa841e04b;
        }
        res = abi.encodePacked(selector, data);
    }

    function _deploy(
        TokenType token,
        bytes memory params
    ) private returns (address) {
        address impl = tokenImplementation[token];
        bytes memory initData = _generateInitData(token, params);
        bytes memory callData = abi.encode(impl, initData);
        bytes memory bytecode = abi.encodePacked(type(Port3NFTFairProxy).creationCode, callData);
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, params));
        address res;
        assembly {
            res := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(res != address(0), "Token failed to deploy");
        emit ProxyCreated(res, token, msg.sender);
        return res;
    }

    function _addAtaMinter(address[] memory _ata) private {
        for (uint256 i = 0; i < _ata.length; i++) {
            _ataAddresses.add(_ata[i]);
        }
        emit AtaAddrAdded(_ata);
    }

    function _removeAtaMinter(address[] memory _ata) private {
        for (uint256 i = 0; i < _ata.length; i++) {
            _ataAddresses.remove(_ata[i]);
        }
        emit AtaAddrRemoved(_ata);
    }
}