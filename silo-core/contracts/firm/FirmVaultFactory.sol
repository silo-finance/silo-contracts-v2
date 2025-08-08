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

    /// @inheritdoc IFirmVaultFactory
    function create(address _initialOwner, ISilo _firmSilo, bytes32 _externalSalt)
        external
        virtual
        returns (IERC4626 firmVault)
    {
        firmVault = IERC4626(Clones.cloneDeterministic(IMPLEMENTATION, _salt(_externalSalt)));
        IFirmVault(address(firmVault)).initialize(_initialOwner, _firmSilo);

        emit NewFirmVault(firmVault);
    }

    function predictAddress(bytes32 _externalSalt, address _deployer)
        external
        view
        returns (address firmVault)
    {
        require(_deployer != address(0), DeployerCannotBeZero());

        firmVault = Clones.predictDeterministicAddress(IMPLEMENTATION, _createSalt(_externalSalt, _deployer));
    }
}
