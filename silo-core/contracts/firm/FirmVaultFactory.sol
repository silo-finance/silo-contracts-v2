// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {Create2Factory} from "common/utils/Create2Factory.sol";

import {FirmVault} from "./FirmVault.sol";
import {IFirmVaultFactory} from "../interfaces/IFirmVaultFactory.sol";
import {IFirmVault} from "../interfaces/IFirmVault.sol";
import {ISilo} from "../interfaces/ISilo.sol";

contract FirmVaultFactory is Create2Factory, IFirmVaultFactory {
    address public immutable IMPLEMENTATION;

    constructor() {
        IMPLEMENTATION = address(new FirmVault());
    }

    function predictAddress(bytes32 _externalSalt, address _deployer)
        external
        view
        returns (address firmVault)
    {
        firmVault = Clones.predictDeterministicAddress(IMPLEMENTATION, _salt(_externalSalt), _deployer);
    }

    /// @inheritdoc IFirmVaultFactory
    function create(address _initialOwner, ISilo _firmSilo, bytes32 _externalSalt)
        external
        virtual
        returns (IERC4626 firmVault)
    {
        bytes32 salt = _salt(_externalSalt);

        firmVault = IERC4626(Clones.cloneDeterministic(IMPLEMENTATION, salt));
        IFirmVault(address(firmVault)).initialize(_initialOwner, _firmSilo);

        emit NewFirmVault(firmVault);
    }
}
