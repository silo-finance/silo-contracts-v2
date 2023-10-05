// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {CommonDeploy, SiloCoreContracts} from "./_CommonDeploy.sol";

import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {SiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {ShareCollateralToken} from "silo-core/contracts/utils/ShareCollateralToken.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloFactoryDeploy.s.sol:SiloFactoryDeploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloFactoryDeploy is CommonDeploy {
    function run() public returns (ISiloFactory siloFactory) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        siloFactory = ISiloFactory(address(new SiloFactory()));

        address siloImpl = address(new Silo(siloFactory));
        address shareCollateralTokenImpl = address(new ShareCollateralToken());
        address shareDebtTokenImpl = address(new ShareDebtToken());

        uint256 daoFeeInBp = 0.15e4;
        address daoFeeReceiver = address(msg.sender);
        // TODO: uncomment when reading from file system is completed
        // address daoFeeReceiver = getDeployedAddress(VeSiloContracts.FEE_DISTRIBUTOR);

        siloFactory.initialize(siloImpl, shareCollateralTokenImpl, shareDebtTokenImpl, daoFeeInBp, daoFeeReceiver);

        // TODO: uncomment when reading from file system is completed
        // address timelock = getDeployedAddress(VeSiloContracts.TIMELOCK_CONTROLLER);
        OwnableUpgradeable(address(siloFactory)).transferOwnership(msg.sender);

        vm.stopBroadcast();

        _registerDeployment(address(siloFactory), SiloCoreContracts.SILO_FACTORY);
        _syncDeployments();
    }
}
