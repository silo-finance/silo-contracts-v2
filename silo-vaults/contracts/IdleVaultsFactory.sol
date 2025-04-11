// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {IERC4626, IERC20Metadata} from "openzeppelin5/interfaces/IERC4626.sol";

import {Create2Factory} from "common/utils/Create2Factory.sol";

import {IIdleVaultsFactory} from "./interfaces/IIdleVaultsFactory.sol";

import {EventsLib} from "./libraries/EventsLib.sol";

import {IdleVault} from "./IdleVault.sol";

abstract contract IdleVaultsFactory is Create2Factory, IIdleVaultsFactory {
    mapping(address => bool) public isIdleVault;

    function createIdleVault(IERC4626 _vault) public virtual returns (IERC4626 idleVault) {
        idleVault = new IdleVault{salt: _salt()}(
            address(_vault),
            _vault.asset(),
            string.concat("IdleVault for ", IERC20Metadata(address(_vault)).name()),
            string.concat("IV-", IERC20Metadata(address(_vault)).symbol())
        );

        isIdleVault[address(idleVault)] = true;

        emit EventsLib.CreateIdleVault(address(idleVault), address(_vault));
    }
}
