// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {ISiloLiquidityGauge} from "ve-silo/contracts/gauges/interfaces/ISiloLiquidityGauge.sol";
import {LiquidityGaugeFactory} from "ve-silo/contracts/gauges/ethereum/LiquidityGaugeFactory.sol";
import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/LiquidityGaugeFactoryDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract LiquidityGaugeFactoryDeploy is CommonDeploy {
    string internal constant _BASE_DIR = "ve-silo/contracts/gauges/ethereum";

    function run() public returns (ILiquidityGaugeFactory gaugeFactory) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address liquidityGaugeImpl = _deploy(
            VeSiloContracts.SILO_LIQUIDITY_GAUGE,
            abi.encode(
                getDeployedAddress(VeSiloContracts.MAINNET_BALANCER_MINTER),
                getDeployedAddress(VeSiloContracts.VE_BOOST),
                getDeployedAddress(VeSiloContracts.TIMELOCK_CONTROLLER)
            )
        );

        LiquidityGaugeFactory factoryAddr = new LiquidityGaugeFactory(ISiloLiquidityGauge(liquidityGaugeImpl));

        _registerDeployment(address(factoryAddr), VeSiloContracts.LIQUIDITY_GAUGE_FACTORY);

        gaugeFactory = ILiquidityGaugeFactory(address(factoryAddr));

        vm.stopBroadcast();

        _syncDeployments();
    }

    function _contractBaseDir() internal pure override virtual returns (string memory) {
        return _BASE_DIR;
    }
}
