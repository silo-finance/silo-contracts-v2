// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable2Step} from "openzeppelin5/access/Ownable2Step.sol";

import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {ISiloLiquidityGauge} from "ve-silo/contracts/gauges/interfaces/ISiloLiquidityGauge.sol";
import {LiquidityGaugeFactory} from "ve-silo/contracts/gauges/ethereum/LiquidityGaugeFactory.sol";
import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/LiquidityGaugeFactoryDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract LiquidityGaugeFactoryDeploy is CommonDeploy {
    string internal constant _BASE_DIR = "ve-silo/contracts/gauges/ethereum";

    function run() public returns (ILiquidityGaugeFactory gaugeFactory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address mainnetBalancerMinter = getDeployedAddress(VeSiloContracts.MAINNET_BALANCER_MINTER);
        address veBoost = getDeployedAddress(VeSiloContracts.VE_BOOST);
        address timelock = getDeployedAddress(VeSiloContracts.TIMELOCK_CONTROLLER);

        vm.startBroadcast(deployerPrivateKey);

        address liquidityGaugeImpl = _deploy(
            VeSiloContracts.SILO_LIQUIDITY_GAUGE,
            abi.encode(mainnetBalancerMinter, veBoost, timelock)
        );

        LiquidityGaugeFactory factoryAddr = new LiquidityGaugeFactory(ISiloLiquidityGauge(liquidityGaugeImpl));

        Ownable2Step(address(factoryAddr)).transferOwnership(timelock);

        vm.stopBroadcast();

        _registerDeployment(address(factoryAddr), VeSiloContracts.LIQUIDITY_GAUGE_FACTORY);
        _syncDeployments();

        gaugeFactory = ILiquidityGaugeFactory(address(factoryAddr));
    }

    function _contractBaseDir() internal pure override virtual returns (string memory) {
        return _BASE_DIR;
    }
}
