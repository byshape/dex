//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IDEX.sol";
import "./ERC20.sol";
import "./Ownable.sol";

/// @title Decentralized exchange contract to buy and sell ERC20 tokens
/// @author Xenia Shape
/// @notice This contract can be used for only the most basic DEX test experiments
contract DEX is IDEX, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;

    /// @dev Emits when the new token was added
    event NewToken(address indexed token);
    /// @dev Emits when trade rates were updated
    event RatesUpdate(address indexed token, uint256 buyRate, uint256 sellRate);
    /// @dev Emits when tokens were bought
    event Buy(address indexed buyer, address indexed token, uint256 amount);
     /// @dev Emits when tokens were sold
    event Sale(address indexed seller, address indexed token, uint256 amount);

    error InvalidAmount(uint256 amount);
    error InvalidToken(address token);
    error TransferFailed(address to, uint256 value);

    /// @dev Ensures that token is supported by DEX
    modifier tokenExists(address token) {
        uint256 id = _tokenIds[token];
        if(
            (id == 0 && address(_tokens[id]) != token) || (id != 0 && address(_tokens[id]) == address(0))
        ) revert InvalidToken(token);
        _;
    }

    // value for performing more accurate division
    uint256 internal immutable _divisionAccuracy;
    /** percent of ETH which is sent to the owner on every tokens' sale
    for example, 50 * 1e16 = 50% */
    uint256 internal immutable _ownerFee;

    // all trading tokens
    ERC20[] internal _tokens;
    // address of token => index in _tokens array
    mapping(address => uint256) internal _tokenIds;

    // address of token => ETH-token rate
    mapping(address => uint256) internal _buyRates;
    // address of token => token-ETH rate
    mapping(address => uint256) internal _sellRates;
    // address of token => amount of buys
    mapping(address => Counters.Counter) internal _buysCounters;
    // address of token => amount of sales
    mapping(address => Counters.Counter) internal _salesCounters;

    constructor(uint256 divisionAccuracy, uint256 ownerFee) Ownable() {
        _divisionAccuracy = divisionAccuracy;
        _ownerFee = ownerFee;
    }

    /// @notice Function for adding a new token
    /// @param tokenConfig Parameters for setting up the token
    /** @dev
    Function can be called only by the contract owner.
    Function emits NewToken event.
    */
    function createToken(TokenConfig memory tokenConfig) external override onlyOwner {
        ERC20 token = new ERC20(
            tokenConfig.name,
            tokenConfig.symbol,
            tokenConfig.decimals,
            tokenConfig.initialSupply,
            address(this)
        );
        _tokens.push(token);
        _tokenIds[address(token)] = _tokens.length - 1;
        emit NewToken(address(token));
    }

    /// @notice Function for setting up buy and sell rates
    /// @param token Address of the token
    /// @param buyRateNew Buy rate
    /// @param sellRateNew Sell rate
    /** @dev
    Function can be called only by the contract owner.
    Function can be called only for the supported token.
    Function emits RatesUpdate event.
    */
    function setupRates(
        address token,
        uint256 buyRateNew,
        uint256 sellRateNew
    ) external override onlyOwner tokenExists(token) {
        _buyRates[token] = buyRateNew;
        _sellRates[token] = sellRateNew;
        emit RatesUpdate(token, buyRateNew, sellRateNew);
    }

    /// @notice Function for buying tokens
    /// @param token Address of the token
    /** @dev
    Function can be called only for the supported token.
    Function calculates the amount of tokens based on sent ETH amount and current buy rate.
    Function allows to buy tokens up to the maximum exchange amount.
    Function sends percent of received ETH to the DEX owner.
    Function emits Transfer and Buy events.
    */
    function buyTokens(address token) external payable override nonReentrant tokenExists(token){
        uint256 tokenAmount = tokensAmountToBuy(token, msg.value);
        if(tokenAmount > maxExchangeToken(token)) revert InvalidAmount(tokenAmount);
        _getToken(token).transfer(msg.sender, tokenAmount);
        _transferETH(_owner, _getOwnerFee(msg.value));
        emit Buy(msg.sender, token, tokenAmount);
        _buysCounters[token].increment();
    }

    /// @notice Function for selling tokens
    /// @param token Address of the token
    /// @param amount Amount of tokens to sell
    /** @dev
    Function can be called only for the supported token.
    Function allows to sell tokens for the ETH value up to the maximum exchange amount.
    Tokens should be approved by owner to DEX contract to be sold.
    Function emits Transfer, Approval and Buy events.
    */
    function sellTokens(address token, uint256 amount) external override nonReentrant tokenExists(token) {
        uint256 ethAmount = amount * sellRate(token);
        if(ethAmount > maxExchangeETH()) revert InvalidAmount(ethAmount);
        _getToken(token).transferFrom(msg.sender, address(this), amount);
        _transferETH(msg.sender, ethAmount);
        emit Sale(msg.sender, token, amount);
        _salesCounters[token].increment();
    }

    /// @notice Function for getting supported tokens
    /// @return Array of tokens' addresses
    /** @dev
    There is a possible contract vulnerability if used in write function: with a large number
    of tokens added, the total gas cost of the calling function may exceed the maximum block gas limit.
    Gas usage need to be measured to determine the maximum possible number of tokens supported.
    */
    function supportedTokens() public view override returns(address[] memory) {
        address[] memory tokens = new address[](_tokens.length);
        for(uint256 i=0; i < _tokens.length; i++) {
            tokens[i] = address(_tokens[i]);
        }
        return tokens;
    }

    /// @notice Function for getting ETH-token rate
    /// @param token Address of the token
    /// @return Buy rate
    function buyRate(address token) public view override tokenExists(token) returns(uint256) {
        return _buyRates[token];
    }

    /// @notice Function for getting token-ETH rate
    /// @param token Address of the token
    /// @return Sell rate
    function sellRate(address token) public view override tokenExists(token) returns(uint256) {
        return _sellRates[token];
    }

    /// @notice Function for getting amount of buys
    /// @param token Address of the token
    /// @return Amount of buys
    function buysAmount(address token) external view override tokenExists(token) returns(uint256) {
        return _buysCounters[token].current();
    }

    /// @notice Function for getting amount of sales
    /// @param token Address of the token
    /// @return Amount of sales
    function salesAmount(address token) external view override tokenExists(token) returns(uint256) {
        return _salesCounters[token].current();
    }

    /// @notice Function for getting the maximum ETH amount to be exchanged
    /// @return DEX ETH balance
    function maxExchangeETH() public view override returns(uint256) {
        return address(this).balance;
    }

    /// @notice Function for getting the maximum tokens amount to be exchanged
    /// @return DEX tokens balance
    /// @dev Function can be called only for the supported token.
    function maxExchangeToken(address token) public view override tokenExists(token) returns(uint256) {
        return _getToken(token).balanceOf(address(this));
    }

    /// @notice Function for calculating the amount of tokens to buy based on ETH amount and current buy rate.
    /// @return DEX tokens balance
    /// @dev Function can be called only for the supported token.
    function tokensAmountToBuy(
        address token,
        uint256 ethAmount
    ) public view override tokenExists(token) returns(uint256) {
        // multiply by _divisionAccuracy for better calculation accuracy
        return _accurateDiv(ethAmount, buyRate(token));
    }

    function _transferETH(address to, uint256 value) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = to.call{value: value}("");
        if (!success) revert TransferFailed(to, value);
    }

    function _getToken(address token) internal view returns(ERC20) {
        return _tokens[_tokenIds[token]];
    }

    function _accurateDiv(uint256 dividend, uint256 divider) internal view returns(uint256) {
        // _divisionAccuracy is used to increase div accuracy
        return dividend * _divisionAccuracy / divider / _divisionAccuracy;
    }

    function _getOwnerFee(uint256 amount) internal view returns(uint256) {
        // 1e18 is used to get _ownerFee like percents
        return amount * _ownerFee / 1e18;
    }
}