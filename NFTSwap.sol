//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IERC721TokenReceiver.sol";
import "./IERC721.sol";

struct Order {
    address owner;
    uint256 price; 
}

contract NFTSwap is IERC721TokenReceiver {

    event List(address indexed seller, address indexed nftAddr, uint256 indexed tokenId, uint256 price);
    event Purchase(address indexed buyer, address indexed nftAddr, uint256 indexed tokenId, uint256 price);
    event Revoke(address indexed seller, address indexed nftAddr, uint256 indexed tokenId);    
    event Update(address indexed seller, address indexed nftAddr, uint256 indexed tokenId, uint256 newPrice);

    mapping(address => mapping(uint256 => Order)) public nftList;    

    receive() external payable {

    }

    function list(address _nftAddr, uint256 _tokenId, uint256 _price) external {
        IERC721 NFT = IERC721(_nftAddr);
        require(NFT.getApproved(_tokenId) == address(this) || NFT.isApprovedForAll(msg.sender, address(this)), "Need Approval");
        require(_price > 0, "Invalid Price");

        Order storage order = nftList[_nftAddr][_tokenId];
        order.owner = msg.sender;
        order.price = _price;
   
        NFT.safeTransferFrom(msg.sender, address(this), _tokenId);

        emit List(msg.sender, _nftAddr, _tokenId, _price);
    }

    function revoke(address _nftAddr, uint256 _tokenId) external {
        Order storage order = nftList[_nftAddr][_tokenId];
        require(order.owner == msg.sender, "Not Owner");
     
        IERC721 NFT = IERC721(_nftAddr);
        require(NFT.ownerOf(_tokenId) == address(this), "Invalid Order");
        
        NFT.safeTransferFrom(address(this), msg.sender, _tokenId);
        delete nftList[_nftAddr][_tokenId];
      
        emit Revoke(msg.sender, _nftAddr, _tokenId);
    }

    function update(address _nftAddr, uint256 _tokenId, uint256 _newPrice) external {
        require(_newPrice > 0, "Invalid Price");

        Order storage order = nftList[_nftAddr][_tokenId];
        require(order.owner == msg.sender, "Not Owner");
 
        IERC721 NFT = IERC721(_nftAddr);
        require(NFT.ownerOf(_tokenId) == address(this), "Invalid Order");
        
        order.price = _newPrice;
      
        emit Update(msg.sender, _nftAddr, _tokenId, _newPrice);
    }

    function purchase(address _nftAddr, uint256 _tokenId) payable external {
        Order storage order = nftList[_nftAddr][_tokenId];  
        require(order.price > 0, "Invalid Price");
        require(msg.value >= order.price, "Increase price");

        IERC721 NFT = IERC721(_nftAddr);
        require(NFT.ownerOf(_tokenId) == address(this), "Invalid Order");

        NFT.safeTransferFrom(address(this), msg.sender, _tokenId);
        
        (bool ownerSuccess, ) = order.owner.call{value: order.price}("");
        require(ownerSuccess, "Pay Fail");

        (bool success, ) = msg.sender.call{value: msg.value - order.price}("");
        require(success, "Pay Fail");

        delete nftList[_nftAddr][_tokenId];

        emit Purchase(msg.sender, _nftAddr, _tokenId, msg.value);
    }

    function onERC721Received(address, address, uint, bytes calldata) external pure override returns (bytes4) {
        return IERC721TokenReceiver.onERC721Received.selector;
    }

}