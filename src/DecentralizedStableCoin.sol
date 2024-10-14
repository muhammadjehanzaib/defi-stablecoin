//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
* @title Decentralized StatbleCoin
* @author Bhatti
*/

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__BurnAmountMustBeMoreThanZero();
    error DecentralizedStableCoin__MintAmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__MintingAddressShouldNotBeZero();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        // require(_amount < balance, "Out of balance");
        if (_amount <= 0) {
            revert DecentralizedStableCoin__BurnAmountMustBeMoreThanZero();
        }
        if (balance <= _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
        if (address(_to) == address(0)) {
            revert DecentralizedStableCoin__MintingAddressShouldNotBeZero();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MintAmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
