// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";


contract MintableToken is ERC20 {
    bool onDemand;

    constructor() ERC20("a", "b") {}

    function mint(address _owner, uint256 _amount) external virtual {
        _mint(_owner, _amount);
    }

    function setOnDemand(bool _onDemand) external {
        onDemand = _onDemand;
    }

    function mintOnDemand(address _owner, uint256 _amount) public virtual {
        uint256 balance = balanceOf(_owner);
        if (balance >= _amount) return;

        _mint(_owner, _amount - balance);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        if (!onDemand) {
            return super.transferFrom(sender, recipient, amount);
        }

        // do whatever to be able to transfer from

        mintOnDemand(sender, amount);

        _transfer(sender, recipient, amount);

        // no allowance!

        return true;
    }
}
