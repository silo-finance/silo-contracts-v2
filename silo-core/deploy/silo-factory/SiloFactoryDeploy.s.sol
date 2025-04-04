// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {CommonDeploy} from "../_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {SiloFactory} from "silo-core/contracts/SiloFactory.sol";

abstract contract SiloFactoryDeploy is CommonDeploy {
    function run() public returns (ISiloFactory siloFactory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address daoFeeReceiver = VeSiloDeployments.get(VeSiloContracts.FEE_DISTRIBUTOR, ChainsLib.chainAlias());
        address owner = _getOwner();

        vm.startBroadcast(deployerPrivateKey);

        siloFactory = ISiloFactory(address(new SiloFactory(daoFeeReceiver)));
        Ownable(address(siloFactory)).transferOwnership(owner);

        vm.stopBroadcast();

        _registerDeployment(address(siloFactory), SiloCoreContracts.SILO_FACTORY);
    }

    function _getOwner() internal virtual returns (address owner) {}
}
