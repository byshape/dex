//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title Ownable contract for storing contract owner
/// @author Xenia Shape
/// @notice This contract can be used for only the most basic test experiments
contract Ownable {
    address internal _owner;

    error NotOwner();

    constructor() {
        _owner = msg.sender;
    }

    /// @dev Ensures that caller is the contract's owner
    modifier onlyOwner {
        if(msg.sender != _owner) revert NotOwner();
        _;
    } 
}