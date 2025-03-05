// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {PendlePTOracleFactory} from "silo-oracles/contracts/pendle/PendlePTOracleFactory.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {IPyYtLpOracleLike} from "silo-oracles/contracts/pendle/interfaces/IPyYtLpOracleLike.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/PendlePTOracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract PendlePTOracleFactoryDeploy is CommonDeploy {
    address pendleOracle;
    bool qaMode;

    modifier withBroadcast() {
        if (!qaMode) {
            uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
            vm.startBroadcast(deployerPrivateKey);
        }

        _;

        if (!qaMode) vm.stopBroadcast();
    }

    function run() public withBroadcast returns (address factory) {
        if (!qaMode) {
            AddrLib.init();
            pendleOracle = AddrLib.getAddress(AddrKey.PENDLE_ORACLE);
        }

        factory = address(new PendlePTOracleFactory(IPyYtLpOracleLike(pendleOracle)));

        if (!qaMode) _registerDeployment(factory, SiloOraclesFactoriesContracts.PENDLE_PT_ORACLE_FACTORY);
    }

    function initQA(address _pendleOracle) external {
        pendleOracle = _pendleOracle;
        qaMode = true;
    }
}
