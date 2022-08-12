// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SushiBar is ERC20("SushiBar", "xSUSHI") {
    IERC20 public sushi;

    //Sushi token contract
    constructor(IERC20 _sushi) {
        sushi = _sushi;
    }

    // keeps track of entry time of a user's skate
    mapping(address => uint256) entryTime;

    // calculates staking time by using entryTime mapping
    function stakeTime(address _user) internal view returns (uint256) {
        uint _stakeTime = block.timestamp - entryTime[_user];
        return _stakeTime;
    }

    // keeps track of xSUSHI tokens for addresses - can be used in timelock and early unstake scenarios
    mapping(address => uint256) tokens;

    // keeps track of sushi token rewards pool
    mapping(IERC20 => uint256) rewards;

    function entry() internal {
        entryTime[msg.sender] = block.timestamp;
    }

    // Enter the bar. Pay some SUSHIs. Earn some shares.
    // Locks Sushi and mints xSushi
    function enter(uint256 _amount) public {
        // Gets the amount of Sushi locked in the contract
        uint256 totalSushi = sushi.balanceOf(address(this));
        // Gets the amount of xSushi in existence
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || totalSushi == 0) {
            _mint(msg.sender, _amount);
            tokens[msg.sender] = _amount;
        } else {
            uint256 data = (_amount * totalShares) / totalSushi;
            _mint(msg.sender, data);
            tokens[msg.sender] += data;
        }
        entry();
        // Lock the Sushi in the contract
        sushi.transferFrom(msg.sender, address(this), _amount);
    }

    modifier unstakeAmount(uint amount) {
        uint _stakeTime = stakeTime(msg.sender);
        require(_stakeTime > 2 days, "0% can be unstaked");
        if (_stakeTime > 2 days && _stakeTime <= 4 days) {
            require(
                amount <= (tokens[msg.sender] * 25) / 100,
                "25% can be unstaked"
            );
        } else if (_stakeTime > 4 days && _stakeTime <= 6 days) {
            require(
                amount <= (tokens[msg.sender] * 50) / 100,
                "50% can be unstaked"
            );
        } else if (_stakeTime > 6 days && _stakeTime <= 8 days) {
            require(
                amount <= (tokens[msg.sender] * 75) / 100,
                "75% can be unstaked"
            );
        } else {
            require(amount <= tokens[msg.sender]);
        }
        _;
    }
    address public rewardsPool;

    // Leave the bar. Claim back your SUSHIs.
    function leave(uint256 _share) public unstakeAmount(_share) {
        uint value = stakeTime(msg.sender);

        uint256 totalShares = totalSupply();

        uint256 data = (_share * sushi.balanceOf(address(this))) / totalShares;
        _burn(msg.sender, _share);

        tokens[msg.sender] -= _share;

        uint amountToSend;
        if (value > 0 days && value <= 2 days) {
            amountToSend = 0;
        } else if (value > 2 days && value <= 4) {
            amountToSend = (data * 25) / 100;
        } else if (value > 4 days && value <= 6 days) {
            amountToSend = (data * 50) / 100;
        } else if (value > 6 days && value <= 8 days) {
            amountToSend = (data * 75) / 100;
        } else if (value > 8 days) {
            amountToSend = data;
        }

        // taxed amount which goes to Rewards pool
        uint amountToPool = data - amountToSend;

        // user recieves amount & the remaining goes to rewards
        bool sent;
        (sent, ) = payable(msg.sender).call{value: amountToSend}("");
        // tokens received on tax will go to rewards pool
        rewards[sushi] += amountToPool;
    }
}
