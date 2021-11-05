//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
//pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract XTNFT is ERC721URIStorage,  Ownable {
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    struct NFTRegisterStruct {
        address _ownerAddress;
        uint256 _tokenId;
        uint256 _expiryTime;
        bool _forSale;
        uint256 _salePrice;
        string _tokenURI;
    }
    
    mapping(string => NFTRegisterStruct) nftNameMap;
    
    //mapping with wallet address for a better performance
    struct UserNFTRegisterStruct {
        uint256[] _tokenIds;
    }
    
    mapping(address => UserNFTRegisterStruct) nftUserTokenMap;
    
    uint256 mintPrice = 30000000000000000000;//30 * 10^18 XTT
    using SafeERC20 for IERC20;
    
    uint256 private _activeTime;

    // ERC20 basic payment token contracts being held
    IERC20 private _tokenForRegisterNFT;
    IERC20 private _tokenForMarketPlace;
    
    // beneficiary of payment
    address private _beneficiary;// = address(this);//0x7C123Ef0010391EC1C47F951A4f5F324691aC7FE;
    
    string[] private _nameXTExt= [".bsc", ".sol", ".eth", ".ada", ".matic", ".icp", ".dot", ".int", ".all"];
    //string[] private _nameIANAExt= [".com"];
    
    uint256 private _marketplaceFee = 2000000000000000000; // 2 % = 2 * 10^18
    
    constructor() ERC721("XT-Domain-NFT", "XT-Domain-NFT") {
        _activeTime = block.timestamp + 24 hours;
        _beneficiary = address(this);
    }
    
    function getActiveTime() public view returns (uint256)
    {
        return _activeTime;
    }
    /*
    function setActiveTime(uint256 activeTime_) external onlyOwner {
        require(
            activeTime_ > getActiveTime(),
            "New active time can't be before the current active time"
        );
        
        require(
            activeTime_ <= getActiveTime() + 14 days,
            "New active time can't be longer than the current active time + 14 days"
        );
        
        _activeTime = activeTime_;
    }
    */
    
    //Declare an Event
    event SetMarketPlaceFee(
        address indexed caller,
        uint256 indexed marketplaceFee_
    );
    
    function setMarketPlaceFee(uint256 marketplaceFee_) external onlyOwner {
        _marketplaceFee = marketplaceFee_;
        emit SetMarketPlaceFee(msg.sender, marketplaceFee_);
    }
    
    //Declare an Event
    event AddXTExt(
        address indexed caller,
        string indexed nameExt_
    );
    
    function addXTExt( string memory nameExt_) external onlyOwner {
        
        uint loopCnt = _nameXTExt.length;
        
        for(uint i=0; i< _nameXTExt.length; i++){
            if (keccak256(abi.encodePacked(nameExt_)) == keccak256(abi.encodePacked(_nameXTExt[i]))){
                loopCnt = i;
                break;
            }
        }
        
        require(
            loopCnt == _nameXTExt.length,
            "The name extension is already existed."
        );
            
        _nameXTExt.push(nameExt_);
        emit AddXTExt(msg.sender, nameExt_);
    }
    
    function getNameExt()  public view returns (string[] memory) {
        return _nameXTExt;
    }
    
    //Declare an Event
    event SetTokenForPayment(
        address indexed caller,
        IERC20 indexed token_
    );
    
    //Declare an Event
    event SetMintPrice(
        address indexed caller,
        uint indexed newMintPrice
    );
    
    function setMintPrice(uint newMintPrice) external onlyOwner {
        mintPrice = newMintPrice;
        emit SetMintPrice(msg.sender, newMintPrice);
    }
    
    function getMintPrice() public view virtual returns (uint256) {
        return mintPrice;
    }
    
    function getCurrentTokenId() public view virtual returns (uint256) {
        return  _tokenIds.current();
    }
    /**
     * @return the token being held.
     */
    function paymentToken(uint paymentId) public view virtual returns (IERC20) {
        if(paymentId == 1) return _tokenForRegisterNFT;
        else if(paymentId == 2) return _tokenForMarketPlace;
        return _tokenForRegisterNFT;
    }
    
    function setTokenForPayment(IERC20 token_) external onlyOwner {
        _tokenForRegisterNFT = token_;
        emit SetTokenForPayment(msg.sender, token_);
    }
    
    function balanceTokenForPayment(uint paymentId) public view virtual returns (uint256) {
        require(
            paymentId <= 2,
            "Unknown payment token"
        );
        
        return paymentToken(paymentId).balanceOf(address(this));
    }
    
    //Declare an Event
    event WithdrawTokenForPayment(
        address indexed caller,
        address indexed beneficiary_,
        uint256 indexed balance_
    );
    
    function withdrawTokenForPayment(uint paymentId) external {
        require(
            paymentId <= 2,
            "Unknown payment token"
        );
        
        uint256 currentBalance = paymentToken(paymentId).balanceOf(address(this));
        paymentToken(paymentId).safeTransferFrom(address(this), beneficiary(), currentBalance);
        emit WithdrawTokenForPayment(address(this), beneficiary(), currentBalance);
    }
    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }
    
    //Declare an Event
    event SetBeneficiary(
        address indexed caller,
        address indexed beneficiary_
    );
    
    function setBeneficiary( address beneficiary_) external onlyOwner {
        require(
            beneficiary_ != address(0),
            "New beneficiary is the zero address"
        );
        
        _beneficiary = beneficiary_;
        emit SetBeneficiary(msg.sender, beneficiary_);
    }
    
    //Declare an Event
    event RegisteredNewNFT(
        address indexed caller,
        string indexed newNFT
    );
    
    function registerNFT(string memory newNFT, uint nameXTExtId_, string memory tokenURI_, uint numOfYear)
        public 
        returns (uint256)
    {
        require(
            block.timestamp > getActiveTime(),
            "ActiveTime: You can't register NFT before the active time."
        );
        
        require(paymentToken(1).balanceOf(msg.sender) >= getMintPrice(), "Can't pay nft fee!");
        
        require(bytes(newNFT).length > 0, "Can't be blank!");
        
        require(numOfYear >= 1, "Can't be less than 1 year!");
        
        //paymentToken().approve(address(this), getMintPrice());
        
        paymentToken(1).safeTransferFrom(msg.sender, address(this), numOfYear * getMintPrice());

        string memory fullNFT = bytes(newNFT).length > 0 ? string(abi.encodePacked(newNFT, _nameXTExt[nameXTExtId_])) : "";
         
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        
        //_mint(recipient, newItemId);
        _mint(msg.sender, newItemId);
        //new Item will be managed by this contract
        //_mint(address(this), newItemId);
        
        //_setTokenURI(newItemId, tokenURI_);
    
        //nftNameMap[bscNFT] = newItemId;
        nftNameMap[fullNFT]._ownerAddress = msg.sender;//recipient;
        nftNameMap[fullNFT]._tokenId = newItemId;
        nftNameMap[fullNFT]._expiryTime = block.timestamp + numOfYear * 365 * 86400;
        //nftNameMap[bscNFT]._isActive = false;
        //nftNameMap[bscNFT]._isBlackListed = false;
        nftNameMap[fullNFT]._forSale = false;
        nftNameMap[fullNFT]._salePrice = 0;
        nftNameMap[fullNFT]._tokenURI = tokenURI_;
        
        //use the map of address with tokenIds for a better performance when get the list of tokenIds by an address
        nftUserTokenMap[msg.sender]._tokenIds.push(newItemId);
        
        //Emit an event
        emit RegisteredNewNFT(msg.sender, fullNFT);
    
        return newItemId;
    }
    
    //Declare an Event
    event ExtendNFTSubscription(
        address indexed caller,
        string indexed newNFT
    );
    
    function extendNFTSubscription(string memory newNFT, uint nameXTExtId_, uint numOfYear)
        public 
    {
        require(
            block.timestamp > getActiveTime(),
            "ActiveTime: You can't register NFT before the active time."
        );
        
        require(paymentToken(1).balanceOf(msg.sender) >= numOfYear * getMintPrice(), "Can't pay nft fee!");
        
        require(bytes(newNFT).length > 0, "Can't be blank!");
        
        require(numOfYear >= 1, "Can't be less than 1 year!");
        
        //paymentToken().approve(address(this), getMintPrice());
        
        paymentToken(1).safeTransferFrom(msg.sender, beneficiary(), numOfYear * getMintPrice());

        string memory fullNFT = bytes(newNFT).length > 0 ? string(abi.encodePacked(newNFT, _nameXTExt[nameXTExtId_])) : "";
         
        //_tokenIds.increment();

        //uint256 newItemId = _tokenIds.current();
        
        //_mint(recipient, newItemId);
        //_mint(msg.sender, newItemId);
        //new Item will be managed by this contract
        //_mint(address(this), newItemId);
        
        //_setTokenURI(newItemId, tokenURI_);
    
        //nftNameMap[bscNFT] = newItemId;
        //nftNameMap[bscNFT]._ownerAddress = msg.sender;//recipient;
        //nftNameMap[bscNFT]._tokenId = newItemId;
        nftNameMap[fullNFT]._expiryTime = block.timestamp + numOfYear * 365 * 86400;
        //nftNameMap[bscNFT]._isActive = false;
        //nftNameMap[bscNFT]._isBlackListed = false;
        //nftNameMap[bscNFT]._forSale = false;
        //nftNameMap[bscNFT]._salePrice = 0;
        //nftNameMap[bscNFT]._tokenURI = tokenURI_;
        
        //use the map of address with tokenIds for a better performance when get the list of tokenIds by an address
        //nftUserTokenMap[msg.sender]._tokenIds.push(newItemId);
        
        //Emit an event
        emit ExtendNFTSubscription(msg.sender, fullNFT);
    
        //return newItemId;
    }
    
    //Declare an Event
    event ImportNewNFT(
        address indexed caller,
        string indexed newNFT
    );
    
    function importNFT(address recipient, string memory newNFT, string memory tokenURI_, uint numOfYear)
        public onlyOwner 
        returns (uint256)
    {
        require(
            block.timestamp > getActiveTime(),
            "ActiveTime: You can't register NFT before the active time."
        );
        
        require(paymentToken(1).balanceOf(msg.sender) >= numOfYear * getMintPrice(), "Can't pay nft fee!");
        
        require(bytes(newNFT).length > 0, "Can't be blank!");
        
        require(numOfYear >= 1, "Can't be less than 1 year!");
        
        //paymentToken().approve(address(this), getMintPrice());
        
        paymentToken(1).safeTransferFrom(msg.sender, beneficiary(), numOfYear * getMintPrice());

        //string memory bscNFT = bytes(newNFT).length > 0 ? string(abi.encodePacked(newNFT, _nameXTExt[nameXTExtId_])) : "";
         
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        
        _mint(recipient, newItemId);
        //_mint(msg.sender, newItemId);
        //new Item will be managed by this contract
        //_mint(address(this), newItemId);
        
        //_setTokenURI(newItemId, tokenURI_);
    
        //nftNameMap[bscNFT] = newItemId;
        nftNameMap[newNFT]._ownerAddress = recipient;
        nftNameMap[newNFT]._tokenId = newItemId;
        nftNameMap[newNFT]._expiryTime = block.timestamp + numOfYear * 365 * 86400;
        //nftNameMap[bscNFT]._isActive = false;
        //nftNameMap[bscNFT]._isBlackListed = false;
        nftNameMap[newNFT]._forSale = false;
        nftNameMap[newNFT]._salePrice = 0;
        nftNameMap[newNFT]._tokenURI = tokenURI_;
        
        //use the map of address with tokenIds for a better performance when get the list of tokenIds by an address
        nftUserTokenMap[recipient]._tokenIds.push(newItemId);
        
        //Emit an event
        emit ImportNewNFT(recipient, newNFT);
    
        return newItemId;
    }
    
    //Declare an Event
    event ExtendImportedNFTSubscription(
        address indexed caller,
        string indexed newNFT,
        uint indexed numOfYear
    );
    
    function extendImportedNFTSubscription(string memory newNFT, uint numOfYear)
        public onlyOwner 
        //returns (uint256)
    {
        require(
            block.timestamp > getActiveTime(),
            "ActiveTime: You can't register NFT before the active time."
        );
        
        require(paymentToken(1).balanceOf(msg.sender) >= numOfYear * getMintPrice(), "Can't pay nft fee!");
        
        require(bytes(newNFT).length > 0, "Can't be blank!");
        
        require(numOfYear >= 1, "Can't be less than 1 year!");
        
        //paymentToken().approve(address(this), getMintPrice());
        
        paymentToken(1).safeTransferFrom(msg.sender, beneficiary(), numOfYear * getMintPrice());

        //string memory bscNFT = bytes(newNFT).length > 0 ? string(abi.encodePacked(newNFT, _nameXTExt[nameXTExtId_])) : "";
         
        //_tokenIds.increment();

        //uint256 newItemId = _tokenIds.current();
        
        //_mint(recipient, newItemId);
        //_mint(msg.sender, newItemId);
        //new Item will be managed by this contract
        //_mint(address(this), newItemId);
        
        //_setTokenURI(newItemId, tokenURI_);
    
        //nftNameMap[bscNFT] = newItemId;
        //nftNameMap[newNFT]._ownerAddress = recipient;
        //nftNameMap[newNFT]._tokenId = newItemId;
        nftNameMap[newNFT]._expiryTime = block.timestamp + numOfYear * 365 * 86400;
        //nftNameMap[bscNFT]._isActive = false;
        //nftNameMap[bscNFT]._isBlackListed = false;
        //nftNameMap[newNFT]._forSale = false;
        //nftNameMap[newNFT]._salePrice = 0;
        //nftNameMap[newNFT]._tokenURI = tokenURI_;
        
        //use the map of address with tokenIds for a better performance when get the list of tokenIds by an address
        //nftUserTokenMap[recipient]._tokenIds.push(newItemId);
        
        //Emit an event
        emit ExtendImportedNFTSubscription(msg.sender, newNFT, numOfYear);
    
        //return newItemId;
    }
    
    //Declare an Event
    event BuyNFTFromMarketPlace(
        address indexed caller,
        string indexed NFTName_
    );
    
    function buyNFTFromMarketPlace(string memory NFTName_)//, uint nameXTExtId_)
        public
    {
        require(
            block.timestamp > getActiveTime(),
            "ActiveTime: You can't buy NFT before the current active time."
        );
        
        require(paymentToken(2).balanceOf(msg.sender) >= nftNameMap[NFTName_]._salePrice, "Can't pay nft fee!");
        
        //require(bytes(newNFT).length > 0, "Can't be blank!");
        
        //require(numOfYear >= 1, "Can't be less than 1 year!");
        
        //string memory bscNFT = bytes(newNFT).length > 0 ? string(abi.encodePacked(newNFT, _nameXTExt[nameXTExtId_])) : "";
        //paymentToken().approve(address(this), getMintPrice());
        
        //Need to approve this contract before this transaction
        safeTransferFrom( nftNameMap[NFTName_]._ownerAddress, address(this), nftNameMap[NFTName_]._tokenId);
        paymentToken(2).safeTransferFrom(msg.sender, address(this), nftNameMap[NFTName_]._salePrice);
        
        paymentToken(2).safeTransferFrom(address(this), nftNameMap[NFTName_]._ownerAddress, (100 - _marketplaceFee ) * nftNameMap[NFTName_]._salePrice / 100);
        //paymentToken().safeTransferFrom(address(this), beneficiary(), _marketplaceFee * nftNameMap[NFTName_]._salePrice / 100);
        //Need to approve this contract before this transaction
        safeTransferFrom( address(this), msg.sender, nftNameMap[NFTName_]._tokenId);

        uint arrayLength = nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds.length;
        
        uint foundId = arrayLength;
        for(uint i = 0; i < nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds.length; i++){
            if((nftNameMap[NFTName_]._tokenId == nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds[i])){
                foundId = i;
                break;
            }
        }
        
        if(foundId < arrayLength){
            nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds[foundId] = nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds[arrayLength - 1];
            nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds.pop();
        }

        nftNameMap[NFTName_]._ownerAddress = msg.sender;//recipient;
        nftNameMap[NFTName_]._forSale = false;
        nftNameMap[NFTName_]._salePrice = 0;
        
        //use the map of address with tokenIds for a better performance when get the list of tokenIds by an address
        nftUserTokenMap[msg.sender]._tokenIds.push(nftNameMap[NFTName_]._tokenId);
        
        //Emit an event
        emit BuyNFTFromMarketPlace(msg.sender, NFTName_);
    }
    
    //Declare an Event
    event SetNFTSalePrice(
        address indexed caller,
        string indexed NFTName_,
        uint256 salePrice_
    );
    
    function setNFTSalePrice(string memory NFTName_, uint256 salePrice_) external {
        
        address owner = nftNameMap[NFTName_]._ownerAddress;
        
        require(
            owner == msg.sender,
            "Ownable: caller is not the current owner"
        );
        
        nftNameMap[NFTName_]._forSale = true;
        nftNameMap[NFTName_]._salePrice = salePrice_;
        emit SetNFTSalePrice(msg.sender, NFTName_, salePrice_);
    }
    
    //get tokenIds by address
    function getTokenIdsByAddress(address walletAddress) public view returns (uint256[] memory tokenIds)
    {
        return  nftUserTokenMap[walletAddress]._tokenIds;
    }
    
    function getNFTURI(string memory NFTName) public view returns (string memory)
    {
        //require(nftNameMap[nft]._isBlackListed == false, "This NFT has been blacklisted.");
        require(nftNameMap[NFTName]._expiryTime > block.timestamp, "This NFT has been expired. Owner need to extend its subscription time.");
        
        return tokenURI(nftNameMap[NFTName]._tokenId);
    }
    
    //Declare an Event
    event SetNFTURI(
        address indexed caller,
        string indexed NFTName_,
        string indexed tokenURI
    );
    
    function setNFTURI(string memory NFTName_, string memory tokenURI) public
    {
        require(paymentToken(1).balanceOf(msg.sender) >= getMintPrice(), "Can't pay nft fee!");
        
        //address owner = ERC721.ownerOf(nftNameMap[nft]._tokenId);
        address owner = nftNameMap[NFTName_]._ownerAddress;
        
        require(
            owner == msg.sender,
            "Ownable: caller is not the current owner"
        );
        
        paymentToken(1).safeTransferFrom(msg.sender, beneficiary(), getMintPrice());
        
        _setTokenURI(nftNameMap[NFTName_]._tokenId, tokenURI);
        emit SetNFTURI(msg.sender, NFTName_, tokenURI);
    }
}
