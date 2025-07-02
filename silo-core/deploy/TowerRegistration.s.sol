// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {Tower} from "silo-core/contracts/utils/Tower.sol";
import {LiquidationHelper, ILiquidationHelper} from "silo-core/contracts/utils/liquidationHelper/LiquidationHelper.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";

/**
    FOUNDRY_PROFILE=core \
    forge script silo-core/deploy/TowerRegistration.s.sol:TowerRegistration \
    --ffi --rpc-url $RPC_SONIC --broadcast
 */
contract TowerRegistration is CommonDeploy {
    function run() public {
        _register("SiloFactory", getDeployedAddress(SiloCoreContracts.SILO_FACTORY));
        _register(_liquidationHelperName(), getDeployedAddress(_liquidationHelperName()));

        _register(
            "ManualLiquidationHelper",
            getDeployedAddress(SiloCoreContracts.MANUAL_LIQUIDATION_HELPER)
        );

        _register("SiloLens", getDeployedAddress(SiloCoreContracts.SILO_LENS));
        _register("SiloLeverage", getDeployedAddress(SiloCoreContracts.SILO_LEVERAGE));
    }

    function _register(string memory _name, address _currentAddress) internal {
        Tower tower = Tower(getDeployedAddress(SiloCoreContracts.TOWER));
        address old = tower.coordinates(_name);

        if (old == _currentAddress) {
            console2.log("[TowerRegistration] %s up to date", _name);
        } else if (old == address(0)) {
            uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
            console2.log("[TowerRegistration] %s will be register at %s", _name, _currentAddress);

            vm.startBroadcast(deployerPrivateKey);

            tower.register(_name, _currentAddress);

            vm.stopBroadcast();
        } else {
            uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
            console2.log("[TowerRegistration] %s will be updated from %s to %s", _name, old, _currentAddress);

            vm.startBroadcast(deployerPrivateKey);

            tower.update(_name, _currentAddress);

            vm.stopBroadcast();
        }
    }

    function _liquidationHelperName() internal view returns (string memory) {
        return string.concat("LiquidationHelper", _resolveAggregatorName());
    }

    function _resolveAggregatorName() internal view returns (string memory) {
        uint256 chainId = getChainId();

        if (chainId == ChainsLib.ANVIL_CHAIN_ID) return "_anvil_";

        address currentAddress = getDeployedAddress(SiloCoreContracts.LIQUIDATION_HELPER);
        address exchangeProxy = LiquidationHelper(currentAddress).EXCHANGE_PROXY();

        if (exchangeProxy == AddrLib.getAddress(AddrKey.EXCHANGE_AGGREGATOR_1INCH)) return AGGREGATOR_1INCH;
        if (exchangeProxy == AddrLib.getAddress(AddrKey.EXCHANGE_AGGREGATOR_ODOS)) return AGGREGATOR_ODOS;
        if (exchangeProxy == AddrLib.getAddress(AddrKey.EXCHANGE_AGGREGATOR_ENSO)) return AGGREGATOR_ENSO;
        if (exchangeProxy == AddrLib.getAddress(AddrKey.EXCHANGE_AGGREGATOR_0X)) return AGGREGATOR_0X;

        revert("unknown exchange proxy");
    }
}
