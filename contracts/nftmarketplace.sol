// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// import "hardhat/console.sol";

contract NFTMarketplace is ERC1155URIStorage, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    uint256 listingPrice = 0.00025 ether;

    // 定义角色
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address payable owner;
    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    event MarketItemCreated (
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    mapping(uint256 => MarketItem) private idToMarketItem;

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function updateListingPrice(uint _listingPrice) public payable {
        require(owner == msg.sender);
        listingPrice = _listingPrice;
    }

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function createToken(string memory tokenURI, uint256 price) public payable returns (uint) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(msg.sender, newTokenId, 1, "");
        _setURI(newTokenId, tokenURI);
        createMarketItem(newTokenId, price);
        return newTokenId;
    }

    function createMarketItem(uint256 tokenId, uint256 price) private {
        require(price > 0, "Price must be at least 1 wei");
        require(msg.value == listingPrice);
        idToMarketItem[tokenId] = MarketItem(tokenId, payable(msg.sender), payable(address(this)), price, false);
        _safeTransferFrom(msg.sender, address(this), tokenId, 1, "");
        emit MarketItemCreated(tokenId , msg.sender, address(this),price,false);
    }

    function resellToken(uint256 tokenId, uint256 price) public payable {
        require(idToMarketItem[tokenId].owner == msg.sender);
        require(msg.value == listingPrice);
        idToMarketItem[tokenId].sold = false;
        idToMarketItem[tokenId].price = price;
        idToMarketItem[tokenId].seller = payable(msg.sender);
        idToMarketItem[tokenId].owner = payable(address(this));
        _itemsSold.decrement();
        _safeTransferFrom(msg.sender, address(this), tokenId, 1, "");
    }

    function createMarketSale(uint256 tokenId) public payable {
        uint price = idToMarketItem[tokenId].price;
        address payable creator = idToMarketItem[tokenId].seller;
        require(msg.value == price);
        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].sold = true;
        idToMarketItem[tokenId].seller = payable(address(0));
        _itemsSold.increment();
        _safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
        payable(owner).transfer(listingPrice);
        payable(creator).transfer(msg.value);
    }

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint itemCount = _tokenIds.current();
        uint unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint currentIndex = 0;
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint i = 0; i < itemCount; i++) 
        {
            if (idToMarketItem[i + 1].owner == address(this)) 
            {
                uint currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;
        for (uint i = 0; i < totalItemCount; i++) {
            // check if nft is mine
            if (idToMarketItem[i + 1].owner == msg.sender) 
            {
                itemCount += 1;
            }
        }
        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) 
            {
                uint currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
