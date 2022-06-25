//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../DEXStructs.sol";

interface IDEX {
    function createToken(TokenConfig memory tokenConfig) external;
    function setupRates(address token, uint256 buyRate_, uint256 sellRate_) external;
    function buyTokens(address token) external payable;
    function sellTokens(address token, uint256 amount) external;

    function supportedTokens() external view returns(address[] memory tokens);
    function buyRate(address token) external view returns(uint256);
    function sellRate(address token) external view returns(uint256);
    function buysAmount(address token) external view returns(uint256);
    function salesAmount(address token) external view returns(uint256);
    function maxExchangeETH() external view returns(uint256);
    function maxExchangeToken(address token) external view returns(uint256);
    function tokensAmountToBuy(address token, uint256 ethAmount) external view returns(uint256);
}