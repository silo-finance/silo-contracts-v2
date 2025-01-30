// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {IERC4626, IERC20Metadata} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISiloVault} from "./interfaces/ISiloVault.sol";
import {ISiloVaultsFactory} from "./interfaces/ISiloVaultsFactory.sol";

import {EventsLib} from "./libraries/EventsLib.sol";

import {SiloVault} from "./SiloVault.sol";
import {IdleVault} from "./IdleVault.sol";
import {VaultIncentivesModule} from "./incentives/VaultIncentivesModule.sol";

contract IdleVaultsFactory {
    mapping(address => bool) public isIdleVault;

    function createIdleVault(
        IERC4626 _vault,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol
    ) external virtual returns (IdleVault idleVault) {
        idleVault = new IdleVault(
            address(_vault),
            _vault.asset(),
            string.concat("IdleVault for ", IERC20Metadata(address(_vault)).name()),
            string.concat("IV-", IERC20Metadata(address(_vault)).symbol())
        );

        isIdleVault[address(idleVault)] = true;

        emit EventsLib.CreateIdleVault(address(idleVault), address(_vault));
    }
}
