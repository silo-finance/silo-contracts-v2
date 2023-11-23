// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {
ERC4626Upgradeable,
ERC20Upgradeable,
IERC20Upgradeable,
IERC20MetadataUpgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

/// @dev MetaSilo is compatible with ERC4626 and all default methods fits here
///
contract MetaSiloERC4626 is ERC4626Upgradeable {
    function deposit(uint256 _amount) external returns (uint256) {
        return deposit(_amount, msg.sender);
    }

    function mint(uint256 _amount) external returns (uint256) {
        return mint(_amount, msg.sender);
    }

    function withdraw(uint256 _amount) external returns (uint256) {
        return withdraw(_amount, msg.sender, msg.sender);
    }

    function redeem(uint256 _amount) external returns (uint256) {
        return redeem(_amount, msg.sender, msg.sender);
    }
}
