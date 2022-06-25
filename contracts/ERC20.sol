//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./interfaces/IERC20.sol";

/// @title ERC20 contract implemented by EIP-20 Token Standard
/// @author Xenia Shape
/// @notice This contract can be used for only the most basic ERC20 test experiments
contract ERC20 is IERC20 {
    // owner => balance
    mapping(address => uint256) private _balances;
    // owner => spender => amount
    mapping(address => mapping(address => uint256)) private _allowances;

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error ZeroAddressMint();
    error ZeroAddressApprove(address owner, address spender);
    error InsufficientAllowance(uint256 value);
    error InsufficientFunds(uint256 value);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 initialSupply,
        address supplyOwner
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _mint(supplyOwner, initialSupply);
    }

    /// @notice Function for getting the owner's balance
    /// @param owner Address of the account
    function balanceOf(address owner) public view override returns (uint256) {
        return _balances[owner];
    }

    /// @notice Function for sending money to the recipient
    /// @param to Recipient's address
    /// @param value Amount to send
    /// @dev Function emits Transfer event
    function transfer(address to, uint256 value) public override returns(bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /// @notice Function for sending money from sender to the recipient
    /// @param from Sender's address
    /// @param to Recipient's address
    /// @param value Amount to send
    /// @dev Amount to send should be more than allowance
    /// @dev Function emits Transfer and Approval events
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        uint256 currentAllowance = allowance(from, msg.sender);
        if (currentAllowance != type(uint256).max) {
            if(currentAllowance < value) revert InsufficientAllowance(value);
            _approve(from, msg.sender, currentAllowance - value);
        }
        
        _transfer(from, to, value);
        return true;
    }

    /// @notice Function for approving tokens to spender
    /// @param spender Spender's address
    /// @param value Amount to approve
    /// @dev Function does not allow to approve from or to the zero address
    /// @dev Function emits Approval event
    function approve(address spender, uint256 value) public override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /// @notice Function for getting the allowance
    /// @param owner Owner's address
    /// @param spender Spender's address
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /// @notice Function for approving tokens from owner to spender
    /// @param owner Owner's address
    /// @param spender Spender's address
    /// @param value Amount to approve
    /// @dev Function does not allow to approve from or to the zero address
    /// @dev Function emits Approval event
    function _approve(address owner, address spender, uint256 value) internal {
        if(owner == address(0)) revert ZeroAddressApprove(owner, spender);
        if(spender == address(0)) revert ZeroAddressApprove(owner, spender);
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /// @notice Function for sending money from sender to the recipient
    /// @param from Sender's address
    /// @param to Recipient's address
    /// @param value Amount to send
    /// @dev Function does not allow to send amount more than balance
    /// @dev Function emits Transfer event
    function _transfer(address from, address to, uint256 value) internal {
        if(_balances[from] < value) revert InsufficientFunds(value);
        _balances[from] -= value;
        _balances[to] += value;
        emit Transfer(from, to, value);
    }

    /// @notice Function for minting tokens to the account
    /// @param owner Address of the account to mint tokens
    /// @param value Amount to mint
    /// @dev Function does not allow to mint to the zero address
    /// @dev Function emits Transfer event
    function _mint(address owner, uint256 value) internal {
        if (owner == address(0)) revert ZeroAddressMint();
        totalSupply += value;
        _balances[owner] += value;
        emit Transfer(address(0), owner, value);
    }
}