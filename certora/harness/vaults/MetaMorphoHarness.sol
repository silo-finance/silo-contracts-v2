// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {
    MetaMorpho
} from "silo-vaults/contracts/MetaMorpho.sol";

contract MetaMorphoHarness is MetaMorpho {
    constructor(
        address owner,
        uint256 initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol
    ) MetaMorpho(owner, initialTimelock, _asset, _name, _symbol) {}
}
