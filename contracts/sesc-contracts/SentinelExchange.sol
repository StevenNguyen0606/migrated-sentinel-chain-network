pragma solidity ^0.4.23;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol";
import "./LCToken.sol";
import "./Whitelist.sol";

/**
  * @title Sentinel Exchange Contract.
  */
contract SentinelExchange is Ownable {

    struct ExchangeInfo {
        bool isWaiting;
        address sender;
        uint256 value;
        string sellCurrency;
        string getCurrency;
    }

    uint256 public currentId;
    address public oracle;
    Whitelist public whitelist;

    mapping(string => address) currencyMap;
    mapping(bytes32 => ExchangeInfo) public exchangeMap;

    event CurrencyAdded(string name, address indexed addr);
    event CurrencyRemoved(string name, address indexed addr);
    event Exchange(bytes32 exchangeId, uint256 value, string sellCurrency, string getCurrency);
    event Success(bytes32 indexed exchangeId, uint256 indexed value);
    event Fail(bytes32 indexed exchangeId, uint256 indexed value);

    modifier isCurrency(string _currency) {
        require(currencyMap[_currency] != address(0), "Currency address must be different from 0x0");
        _;
    }

    constructor(Whitelist _whitelist, address _oracle) public {
        require(_oracle != address(0), "Oracle address must be different from 0x0");
        whitelist = _whitelist;
        oracle = _oracle;
    }

    function startExchange(
        address sender,
        uint256 value,
        string sellCurrency,
        string getCurrency
    ) internal {
        require(value > 0, "Value not be zero");
        bytes32 idHash = keccak256(currentId);
        exchangeMap[idHash].isWaiting = true;
        exchangeMap[idHash].sender = sender;
        exchangeMap[idHash].value = value;
        exchangeMap[idHash].sellCurrency = sellCurrency;
        exchangeMap[idHash].getCurrency = getCurrency;
        currentId++;
        emit Exchange(idHash, value, sellCurrency, getCurrency);
    }

    /**
     * @dev This function start an exchange of SENI by LCToken
     * @param _currency specify the symbol of the LCToken
     */
    function exchangeSeni(string _currency) external payable isCurrency(_currency) {
        require(whitelist.isWhitelist(msg.sender), "Sender must be whitelisted");
        startExchange(msg.sender, msg.value, "SENI", _currency);
    }

    /**
     * @dev This function start an exchange of LCToken by SENI
     * @param _sender The seller's address
     * @param _value The amount that will be exchanged
     * @param _currency Specify the symbol of the LCToken to be exchanged
     */
    function exchangeLct(address _sender, uint256 _value, string _currency)
      external isCurrency(_currency)
    {
        require(msg.sender == currencyMap[_currency], "Sender mus be the currency address");
        startExchange(_sender, _value, _currency, "SENI");
    }

    /**
     * @dev This function is only executed by the oracle and ends the exchange process
     * @param _exchangeId The id of the exchange to be finalized
     * @param _value The amount that will be transferred
     */
    function callback(bytes32 _exchangeId, uint256 _value) external {
        ExchangeInfo memory info = exchangeMap[_exchangeId];
        require(info.isWaiting, "Exchange must be waiting");
        require(msg.sender == oracle, "Sender must be the oracle address");
        exchangeMap[_exchangeId].isWaiting = false;
        if (keccak256(info.getCurrency) == keccak256("SENI")) {
            if (address(this).balance >= _value) {
                info.sender.transfer(_value);
                LCToken(currencyMap[info.sellCurrency]).burn(info.value);
                emit Success(_exchangeId, _value);
            } else {
                LCToken(currencyMap[info.sellCurrency]).transferFromOwner(info.sender, info.value);
                emit Fail(_exchangeId, _value);
            }
        } else {
            LCToken(currencyMap[info.getCurrency]).mint(info.sender, _value);
            emit Success(_exchangeId, _value);
        }
    }

    /**
     * @notice The `claimTokens()` should only be called if a security issue is found.
     * @param _token to transfer, use 0x0 for ether.
     * @param _to the recipient that receives the tokens/ethers.
     */
    function claimTokens(address _token, address _to) external onlyOwner {
        require(_to != address(0), "To address must be different from 0x0");
        if (_token == address(0)) {
            _to.transfer(address(this).balance);
            return;
        }

        ERC20Basic token = ERC20Basic(_token);
        uint256 balance = token.balanceOf(this);
        require(token.transfer(_to, balance), "Transfer should be successfully");
    }

    /**
     * @dev This function retrieves the address of an registered currency
     * @param _name The symbol of the currency
     * @return The address of the currency
     */
    function currency(string _name) external view returns(address) {
        return currencyMap[_name];
    }

    /**
     * @dev This function adds a new currency to the mapping
     * @param _currency The address of the LCToken currency
     */
    function setCurrency(LCToken _currency) external onlyOwner {
        currencyMap[_currency.symbol()] = _currency;
        emit CurrencyAdded(_currency.symbol(), _currency);
    }

    /**
     * @dev This function removes an existing currency from mapping
     * @param _name The simbol name of the LCToken currency
     */
    function removeCurrency(string _name) external onlyOwner {
        LCToken(currencyMap[_name]).transferOwnership(msg.sender);
        currencyMap[_name] = address(0);
        emit CurrencyRemoved(_name, currencyMap[_name]);
    }

    /**
     * @dev The oracle variable setter
     * @param _oracle The address of the oracle
     */
    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }
}
