//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
//pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract XTNFT is ERC721URIStorage,  Ownable {
    
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIds;
    
    /*
    struct NFTVoteStruct {
        uint256 _tokenId;
        bool _isBlackListed;
    }
    
    mapping(address => NFTVoteStruct) nftVoteMap;
    */
    address[] private _voterArray =  [0x7C123Ef0010391EC1C47F951A4f5F324691aC7FE, 0x35C491E8f286E93913e634d90cd39A7F94d45A71];
    
    struct NFTRegisterStruct {
        address _ownerAddress;
        uint256 _tokenId;
        uint256 _expiryTime;
        //bool _isActive;
        bool _isBlackListed;
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
    
    uint256 mintPrice = 30000000000000000000;//15 * 10^18
    using SafeERC20 for IERC20;
    
    uint256 private _activeTime;

    // ERC20 basic token contract being held
    IERC20 private _token;
    
    // beneficiary of payment
    address private _beneficiary = 0x7C123Ef0010391EC1C47F951A4f5F324691aC7FE;
    
    string[] private _nameExt= [".bsc"];
    
    uint256 private _marketplaceFee = 2000000000000000000; // 2 %= 2 * 10^18
    
    constructor() ERC721("BSC-NFT", "Name-NFT") {
        _activeTime = block.timestamp + 24 hours;
    }
    
    function getActiveTime() public view returns (uint256)
    {
        return _activeTime;
    }

    function setActiveTime(uint256 activeTime_) external onlyOwner {
        require(
            activeTime_ > getActiveTime(),
            "ActiveTime: new active time can't be before the current active time"
        );
        
        require(
            activeTime_ <= getActiveTime() + 14 days,
            "ActiveTime: new active time can't be longer than the current active time + 14 days"
        );
        
        _activeTime = activeTime_;
    }
    
    function setMarketPlaceFee(uint256 marketplaceFee_) external onlyOwner {
        _marketplaceFee = marketplaceFee_;
    }
    
    function getNameExt()  public view returns (string[] memory) {
        return _nameExt;
    }
    
    function setNameExt(string memory nameExt_, uint nameExtId_) external onlyOwner {
        _nameExt[nameExtId_] = nameExt_;
    }
    
    function setTokenForPayment(IERC20 token_) external onlyOwner {
        _token = token_;
    }
    
    function balanceTokenForPayment(address recipient) public view virtual returns (uint256) {
        return paymentToken().balanceOf(recipient);
    }
    
    function setMintPrice(uint newMintPrice) external onlyOwner {
        mintPrice = newMintPrice;
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
    function paymentToken() public view virtual returns (IERC20) {
        return _token;
    }
    
    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }
    
    function setBeneficiary( address beneficiary_) external onlyOwner {
        require(
            beneficiary_ != address(0),
            "beneficiary: new beneficiary is the zero address"
        );
        
        _beneficiary = beneficiary_;
    }
    
    function addWorker( address worker_) external onlyOwner {
        require(
            worker_ != address(0),
            "worker: new worker is the zero address"
        );
        
        _voterArray.push(worker_);
    }
    
    function removeWorker( address worker_) external onlyOwner {
        require(
            worker_ != address(0),
            "worker: new worker is the zero address"
        );
        
        uint loopCnt = _voterArray.length;
        
        for(uint i=0; i< _voterArray.length; i++){
            if(msg.sender == _voterArray[i]){
                _voterArray[i] = address(0);
                loopCnt = i;
                break;
            }
        }
        
        if(loopCnt == _voterArray.length)
            require(
                loopCnt < _voterArray.length,
                "worker: can't find the worker to replace"
            );
    }
    
    //Declare an Event
    event RegisteredNewNFT(
        address indexed caller,
        string indexed newNFT
    );
    
    //function mintNFT(address recipient, bytes32 nft, string memory tokenURI)
    //function mintNFT(address recipient, string memory newNFT, string memory tokenURI)
    //function registerNFT(address recipient, string memory newNFT, uint nameExtId_, string memory tokenURI_, uint numOfYear)
    function registerNFT(string memory newNFT, uint nameExtId_, string memory tokenURI_, uint numOfYear)
        public 
        returns (uint256)
    {
        require(
            block.timestamp > getActiveTime(),
            "ActiveTime: You can't register NFT before the current active time."
        );
        
        require(paymentToken().balanceOf(msg.sender) >= getMintPrice(), "Can't pay nft fee!");
        
        require(bytes(newNFT).length > 0, "Can't be blank!");
        
        require(numOfYear >= 1, "Can't be less than 1 year!");
        
        //paymentToken().approve(address(this), getMintPrice());
        
        paymentToken().safeTransferFrom(msg.sender, beneficiary(), getMintPrice());

        string memory bscNFT = bytes(newNFT).length > 0 ? string(abi.encodePacked(newNFT, _nameExt[nameExtId_])) : "";
         
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        
        //_mint(recipient, newItemId);
        //_mint(msg.sender, newItemId);
        //new Item will be managed by this contract
        //_mint(address(this), newItemId);
        
        //_setTokenURI(newItemId, tokenURI_);
    
        //nftNameMap[bscNFT] = newItemId;
        nftNameMap[bscNFT]._ownerAddress = msg.sender;//recipient;
        nftNameMap[bscNFT]._tokenId = newItemId;
        nftNameMap[bscNFT]._expiryTime = block.timestamp + numOfYear * 365 * 86400;
        //nftNameMap[bscNFT]._isActive = false;
        nftNameMap[bscNFT]._isBlackListed = false;
        nftNameMap[bscNFT]._forSale = false;
        nftNameMap[bscNFT]._salePrice = 0;
        nftNameMap[bscNFT]._tokenURI = tokenURI_;
        
        //use the map of address with tokenIds for a better performance when get the list of tokenIds by an address
        nftUserTokenMap[msg.sender]._tokenIds.push(newItemId);
        
        //Emit an event
        emit RegisteredNewNFT(msg.sender, bscNFT);
    
        return newItemId;
    }
    
    function buyNFT(string memory NFTName_)//, uint nameExtId_)
        public
    {
        require(
            block.timestamp > getActiveTime(),
            "ActiveTime: You can't buy NFT before the current active time."
        );
        
        require(paymentToken().balanceOf(msg.sender) >= nftNameMap[NFTName_]._salePrice, "Can't pay nft fee!");
        
        //require(bytes(newNFT).length > 0, "Can't be blank!");
        
        //require(numOfYear >= 1, "Can't be less than 1 year!");
        
        //string memory bscNFT = bytes(newNFT).length > 0 ? string(abi.encodePacked(newNFT, _nameExt[nameExtId_])) : "";
        //paymentToken().approve(address(this), getMintPrice());
        
        //Need to approve this contract before this transaction
        paymentToken().safeTransferFrom(msg.sender, beneficiary(), nftNameMap[NFTName_]._salePrice);
        //Need to approve this contract before this transaction
        safeTransferFrom( nftNameMap[NFTName_]._ownerAddress, msg.sender, nftNameMap[NFTName_]._tokenId);
        //_tokenIds.increment();

        //uint256 newItemId = _tokenIds.current();
        
        //_mint(recipient, newItemId);
        //_mint(msg.sender, newItemId);
        //new Item will be managed by this contract
        //_mint(address(this), newItemId);
        
        //_setTokenURI(newItemId, tokenURI_);
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
            nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds.pop();//[foundId];
        }
        //nftNameMap[bscNFT] = newItemId;
        nftNameMap[NFTName_]._ownerAddress = msg.sender;//recipient;
        //nftNameMap[NFTName_]._tokenId = newItemId;
        //nftNameMap[NFTName_]._expiryTime = block.timestamp + numOfYear * 365 * 86400;
        //nftNameMap[bscNFT]._isActive = false;
        //nftNameMap[NFTName_]._isBlackListed = false;
        nftNameMap[NFTName_]._forSale = false;
        nftNameMap[NFTName_]._salePrice = 0;
        //nftNameMap[NFTName_]._tokenURI = tokenURI_;
        
        //use the map of address with tokenIds for a better performance when get the list of tokenIds by an address
        nftUserTokenMap[msg.sender]._tokenIds.push(nftNameMap[NFTName_]._tokenId);
        
        //Emit an event
        emit RegisteredNewNFT(msg.sender, NFTName_);
    }
    
    function setNFTSalePrice(string memory NFTName_, uint256 salePrice_) external {
        
        address owner = nftNameMap[NFTName_]._ownerAddress;
        
        require(
            owner == msg.sender,
            "Ownable: caller is not the current owner"
        );
        
        nftNameMap[NFTName_]._forSale = true;
        nftNameMap[NFTName_]._salePrice = salePrice_;
    }
    
    //NFT exchange
    
    
    //get tokenIds by address
    function getTokenIdsByAddress(address walletAddress) public view returns (uint256[] memory tokenIds)
    {
        return  nftUserTokenMap[walletAddress]._tokenIds;
    }
    
    function blacklistNFT(string memory newNFT)
        public 
        //returns (uint256)
    {
        uint foundAddressID = _voterArray.length;
 
        //require(
           // recipient != address(0),
            //"recipient: the recipient is the zero address"
        //);
        
        for(uint i=0; i< _voterArray.length; i++){
            if(msg.sender == _voterArray[i]){
                foundAddressID = i;
                break;
            }
        }
        
        require(foundAddressID == _voterArray.length, "There is no permission to blacklist NFT");
        
        //require(token().balanceOf(address(this)) >= mintPrice, "There is not enough fund pay minting fee!");
         
        //_tokenIds.increment();

        //uint256 newItemId = _tokenIds.current();
        //_mint(recipient, newItemId);
        //_setTokenURI(newItemId, tokenURI);
        
        //nftNameMap[newNFT] = newItemId;
        require(_exists(nftNameMap[newNFT]._tokenId), "ERC721Metadata: URI query for nonexistent token");
        //nftNameMap[newNFT]._isActive = true;
        nftNameMap[newNFT]._isBlackListed = true;
        
        //return newItemId;
    }
    /*
    //function mintNFT(address recipient, string memory newNFT, string memory tokenURI)
    function mintNFT(string memory newNFT)
        public 
        //returns (uint256)
    {
        uint foundAddressID = _voterArray.length;
 
        //require(
           // recipient != address(0),
            //"recipient: the recipient is the zero address"
        //);
        
        for(uint i=0; i< _voterArray.length; i++){
            if(msg.sender == _voterArray[i]){
                foundAddressID = i;
                break;
            }
        }
        
        require(foundAddressID == _voterArray.length, "There is no permission to mint NFT");
        
        //require(token().balanceOf(address(this)) >= mintPrice, "There is not enough fund pay minting fee!");
         
        //_tokenIds.increment();

        //uint256 newItemId = _tokenIds.current();
        //_mint(recipient, newItemId);
        //_setTokenURI(newItemId, tokenURI);
        
        //nftNameMap[newNFT] = newItemId;
        require(_exists(nftNameMap[newNFT]._tokenId), "ERC721Metadata: URI query for nonexistent token");
        nftNameMap[newNFT]._isActive = true;
        //nftNameMap[newNFT]._isBlackListed = false;
        
        //return newItemId;
    }*/
    
    function setNFTURI(string memory nft, string memory tokenURI) public
    {
        require(paymentToken().balanceOf(msg.sender) >= getMintPrice(), "Can't pay nft fee!");
        
        //address owner = ERC721.ownerOf(nftNameMap[nft]._tokenId);
        address owner = nftNameMap[nft]._ownerAddress;
        
        require(
            owner == msg.sender,
            "Ownable: caller is not the current owner"
        );
        
        paymentToken().safeTransferFrom(msg.sender, beneficiary(), getMintPrice());
        
        _setTokenURI(nftNameMap[nft]._tokenId, tokenURI);
    }
    
    function getNFTURI(string memory nft) public view returns (string memory)
    {
        require(nftNameMap[nft]._isBlackListed == false, "This NFT has been blacklisted.");
        require(nftNameMap[nft]._expiryTime > block.timestamp, "This NFT has been expired. Owner need to extend its subscription time.");
        
        return tokenURI(nftNameMap[nft]._tokenId);
    }
}
