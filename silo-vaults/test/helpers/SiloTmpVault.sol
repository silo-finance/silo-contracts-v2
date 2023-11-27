// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {INotificationReceiver} from "../../contracts/SiloIncentivesController.sol";

contract SiloTmpVault is ERC20 {
    INotificationReceiver public nr;

    constructor() ERC20("SiloTmpVault", "STV") {
    }

    function setNotificationReceiver(INotificationReceiver _nr) external {
        nr = _nr;
    }

    function deposit(uint256 _assets) external {
        _mint(msg.sender, _assets);
    }

    function deposit(uint256 _assets, address _receiver) external {
        _mint(_receiver, _assets);
    }

    function withdraw(uint256 _assets) external {
        _burn(msg.sender, _assets);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override virtual {
        nr.onAfterTransfer(address(this), from, to, amount);
    }
}
