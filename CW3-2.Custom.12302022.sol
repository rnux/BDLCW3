// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.7;

/**
 * @dev A contract module that prevents reentrant function calls.
 *
 * Inheriting from 'ReentrancyGuard' gives functions the
 * 'noReentrancy' modifier, which prevents nested (reentrant) calls.
 * Reference: https://blog.openzeppelin.com/reentrancy-after-istanbul/
 *
 */
abstract contract ReentrancyGuard {
    bytes1 private constant _pos1 = "0";
    bytes1 private constant _pos2 = "1";
    bytes1 private _statPos;

    // Logging
    string constant _rLog = "Reentrancy Log";

    constructor(){
        _statPos = _pos1;
    }

    /**
     * @dev Prevents a contract from recalling itself
     */
    modifier noReentrancy(){
        _before();
        _;
        _after();
    }

    function _before() private {
        //First call
        require(_statPos=="0", _rLog);
        //Second call
        _statPos = _pos2;
    }

    function _after() private {
        //restore
        _statPos = _pos1;
    }
}

/**
* @dev  ABI signature for Deployed CustomLib on 0x9DA4c8B1918BA29eBA145Ee3616BCDFcFAA2FC51
*/
library DeployedLibrary {
    function customSend(uint256 value, address receiver) external returns (bool){}
}

/**
 * @dev Required public APIs, referring from ERC20 standard with additional functions and events
 * Reference: https://eips.ethereum.org/EIPS/eip-20
 *
 */
interface PublicAPI {
    // @dev List of standard functions
    function totalSupply() external view returns(uint256);
    function balanceOf(address _account) external view returns(uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function getName() external view returns(string memory);
    function getSymbol() external view returns(string memory);

    // @Dev List of additional functions
    function mint(address to, uint256 value) external returns (bool);
    function sell(uint256 value) external returns (bool);
    function close() external;
    function getPrice() external view returns(uint256);

    // @dev Emitted when tokens are moved from one account to another.
    event Transfer(address indexed from, address indexed to, uint256 value);

    // @dev Emitted when additional amount of token has been minted.
    event Mint(address indexed to, uint256 value);

    // @dev Emitted when an account selling owned token to the contract.
    event Sell(address indexed from, uint256 value);
}

// -----------------------------------------------
/// @title  : Highlander (HLND) - ERC20 Token
/// @author : S2438505
// -----------------------------------------------
contract Token is PublicAPI, ReentrancyGuard {
    // @dev Implement CustomLib
    using DeployedLibrary for uint256;

    /**
     * @dev Token owner information
     */
    struct holderInfomation {
        uint256 balance;
        uint256 timeToWait;
    }
    
    /**
     * @dev Token definition variables
     */
    uint256 private immutable _tMaxSupply; //Token maximum distributable supply
    uint256 private immutable _tPrice; //Token price
    uint256 private immutable _ttwSeconds; //Time to wait in seconds
    uint256 private _tTotalSupply; //Token total supply

    string private _tName; //Token name
    string private _tSymbol; //Token symbol
  
    address payable public owner;
    mapping(address => holderInfomation) private _holder;

    /**
     * @dev Initializing  values
     *      Set as payable to enable anyone to send Ether to the contract
     */
    constructor(string memory name, string memory symbol, uint256 maxTokenSupply, uint256 priceInWei, uint256 timeToWaitSeconds) {
        owner = payable(msg.sender);
        _tName = name;
        _tSymbol = symbol;
        _tPrice = priceInWei;                  
        _tMaxSupply = maxTokenSupply;
        _ttwSeconds = timeToWaitSeconds;
    }

    /**
     * @dev Fallback functions to receive and keep ether
     *      Reference: https://docs.soliditylang.org/en/v0.8.9/contracts.html?highlight=receive#receive-ether-function
     **/

    //@dev Usable for plain Ether transfers
    receive() external payable {
    }

    //@dev Usable for all called messages sent to the contract, except plain Ether transfers
    fallback() external payable {
    }

    /**
     * Exception Constants
    **/
    string constant _eOwner = "Accessible only by owner";
    string constant _eMaxReached = "Maximum supply reached";
    string constant _eZeroAddress = "Zero address is not allowed";
    string constant _eInsufficient = "Insufficient balance";
    string constant _eSell = "Wei transfer failed";
    string constant _eWait = "Window time locked";
    
    /**
     * Modifiers
    **/
    // @dev Makes a function callable only by the owner.
    modifier onlyOwner {
        require(msg.sender == owner, _eOwner);
        _;
    }

    // @dev Check remaining supply to distribute.
    //      Prevent token issuance from exceeding the supply cap. 
    modifier isExceedCap(uint256 _cVal){
        require((_tTotalSupply + _cVal)<=_tMaxSupply, _eMaxReached);
        _;
    }
    
    // @dev Zero/unknown address checking
    modifier nonZero(address _cAddress){
        require(_cAddress != address(0),_eZeroAddress);
        _;
    }

    // @dev Account balance checking
    modifier eligibleBalance(address _cAddress, uint256 _cVal){
        require(balanceOf(_cAddress) >= _cVal, _eInsufficient);
        _;
    }

    // @dev Execution window time checking
    modifier eligibleTime(address _cAddress){
        require(block.timestamp > _holder[_cAddress].timeToWait, _eWait);
        _holder[_cAddress].timeToWait = block.timestamp + _ttwSeconds;
        _;
    }

    /**
     * @dev Transfers value amount of Ether between the caller’s address and the address to.
     */
    function transfer(address _cReceiver, uint256 _cTokenAmt) 
        nonZero(msg.sender) 
        nonZero(_cReceiver)
        eligibleBalance(msg.sender, _cTokenAmt)
        eligibleTime(msg.sender)
        noReentrancy 
        public override returns (bool){
            _holder[msg.sender].balance -= _cTokenAmt;
            _holder[_cReceiver].balance += _cTokenAmt;
            emit Transfer(msg.sender, _cReceiver, _cTokenAmt);

            // @dev Delete variables to save space and refund gas
            delete _cReceiver;
            delete _cTokenAmt;

            return true;
    }

    /**
     * @dev Creates certain amount of tokens and assigns them to 'account', 
     *      increasing the total supply in Ether.
     */  
    function mint(address _cAccount, uint256 _cTokenAmt) 
        nonZero(_cAccount)
        isExceedCap(_cTokenAmt)
        noReentrancy
        public onlyOwner override returns (bool){
            _tTotalSupply += _cTokenAmt;
            _holder[_cAccount].balance += _cTokenAmt;
            emit Mint(_cAccount, _cTokenAmt);

            // @dev Delete variables to save space and refund gas
            delete _cAccount;
            delete _cTokenAmt;

            return true;
    }

    /**
     * @dev Enables a user to sell tokens for wei at a price of 600 wei per token to the contract.
     *      As stated that sold tokens are removed from the circulating supply, then it 
     *      has a degree of similarity with burn, hence reducing the total supply.
     */
    function sell(uint256 _cTokenAmt) 
        nonZero(msg.sender)
        noReentrancy
        eligibleBalance(msg.sender, _cTokenAmt)
        eligibleTime(msg.sender)
        public  override returns(bool){
            uint256 _weiReceived = _cTokenAmt * _tPrice;

            //Calculate selling reward before move on to settlement on the contract
            bool _success = _weiReceived.customSend(msg.sender);
            require(_success, _eSell);

            //Settlement: Sold token removed from circulating supply        
            _tTotalSupply -= _cTokenAmt;
            //Settlement: Sold token deducted from account balance
            _holder[msg.sender].balance -= _cTokenAmt;
                                
            emit Sell(msg.sender, _cTokenAmt);

            // @dev Delete variables to save space and refund gas
            delete _weiReceived;
            delete _cTokenAmt;
            delete _success;
            
            return _success;
    }

    /**
     * @dev Returns total amount of minted tokens.
     */
    function totalSupply() public view override returns (uint256){
        return _tTotalSupply;
    }
    
    /**
     * @dev Returns the amount of tokens an address owns.
     */
    function balanceOf(address _cAccount) public view override returns (uint256){
        return _holder[_cAccount].balance;
    } 

    /**
     * @dev Enables only the owner to destroy the contract.
     */
    function close() public override onlyOwner  {
        selfdestruct(owner);
    }

    /**
     * @dev Returns a string with the token’s name
     */
    function getName() public view override returns (string memory) {
        return _tName;
    } 

    /**
     * @dev Returns a string with the token’s symbol
     */
    function getSymbol() public view override returns (string memory) {
        return _tSymbol;
    }    

    /**
     * @dev Returns the token’s price
     */
    function getPrice() public view override returns (uint256){
        return _tPrice;
    }
}
