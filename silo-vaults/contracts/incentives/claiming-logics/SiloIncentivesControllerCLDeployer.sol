// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISiloIncentivesControllerCLFactory} from "../../interfaces/ISiloIncentivesControllerCLFactory.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {IVaultIncentivesModule} from "silo-vaults/contracts/interfaces/IVaultIncentivesModule.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {GaugeHookReceiver} from "silo-core/contracts/hooks/gauge/GaugeHookReceiver.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {Create2Factory} from "common/utils/Create2Factory.sol";
import {
    SiloIncentivesControllerCL
} from "silo-vaults/contracts/incentives/claiming-logics/SiloIncentivesControllerCL.sol";
import {
    ISiloIncentivesControllerCLDeployer
} from "silo-vaults/contracts/interfaces/ISiloIncentivesControllerCLDeployer.sol";

/// @dev Factory for creating SiloIncentivesControllerCL instances
contract SiloIncentivesControllerCLDeployer is Create2Factory, ISiloIncentivesControllerCLDeployer {
    /// @dev ISiloIncentivesControllerCLFactory to deploy claiming logics.
    ISiloIncentivesControllerCLFactory public immutable CL_FACTORY; // solhint-disable-line var-name-mixedcase

    constructor(ISiloIncentivesControllerCLFactory _siloIncentivesControllerCLFactory) {
        require(address(_siloIncentivesControllerCLFactory) != address(0), EmptyCLFactory());
        require(!_siloIncentivesControllerCLFactory.createdInFactory(address(0)), InvalidCLFactory());

        CL_FACTORY = _siloIncentivesControllerCLFactory;
    }

    /// @inheritdoc ISiloIncentivesControllerCLDeployer
    function createIncentivesControllerCL(
        address _siloVault,
        address _market
    ) external returns (SiloIncentivesControllerCL logic) {
        logic = CL_FACTORY.createIncentivesControllerCL({
            _vaultIncentivesController: address(resolveSiloVaultIncentivesController(_siloVault)),
            _siloIncentivesController: address(resolveMarketIncentivesController(_market)),
            _externalSalt: _salt()
        });
    }

    /// @inheritdoc ISiloIncentivesControllerCLDeployer
    function resolveSiloVaultIncentivesController(address _siloVault)
        public
        view
        returns (ISiloIncentivesController controller)
    {
        IVaultIncentivesModule vaultIncentivesModule = ISiloVault(_siloVault).INCENTIVES_MODULE();
        address[] memory notificationReceivers = vaultIncentivesModule.getNotificationReceivers();

        require(notificationReceivers.length == 1, MoreThanOneSiloVaultNotificationReceiver());
        controller = ISiloIncentivesController(notificationReceivers[0]);
    }
    
    /// @inheritdoc ISiloIncentivesControllerCLDeployer
    function resolveMarketIncentivesController(address _market)
        public
        view
        returns (ISiloIncentivesController controller)
    {
        ISiloConfig.ConfigData memory configData = ISilo(_market).config().getConfig(_market);
        GaugeHookReceiver hookReceiver = GaugeHookReceiver(configData.hookReceiver);
        address gauge = address(hookReceiver.configuredGauges(IShareToken(_market)));

        require(gauge != address(0), UnderlyingMarketDoesNotHaveIncentives());
        controller = ISiloIncentivesController(gauge);
    }
}
