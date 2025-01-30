// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ERC20, ERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

contract MockERC4626 is ERC4626 {
    /// @dev Initializes the contract.
    /// @param _asset The address of the underlying asset.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    constructor(
        address _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(IERC20(_asset)) ERC20(_name, _symbol) {}
}
