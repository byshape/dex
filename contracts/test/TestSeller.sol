//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interfaces/IDEX.sol";
import "../interfaces/IERC20.sol";

/** @title
Test seller contract to test inability to sell tokens on DEX contract
without being able to receive ETH.
*/
/// @author Xenia Shape
/// @notice This contract can be used for only the test experiments
contract TestSeller {
    IDEX internal _dex;
    IERC20 internal _token;

    constructor(IDEX dex, IERC20 token) {
        _dex = dex;
        _token = token;
    }

    /// @dev This function will be always reverted with TransferFailed error
    function buyAndSellTokens() external payable{
        _dex.buyTokens{value: msg.value}(address(_token));
        uint256 amount = _dex.tokensAmountToBuy(address(_token), msg.value);
        _token.approve(address(_dex), amount);
        _dex.sellTokens(address(_token), amount);
    }
}