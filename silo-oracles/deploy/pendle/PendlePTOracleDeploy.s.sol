// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {PendlePTOracleFactory} from "silo-oracles/contracts/pendle/PendlePTOracleFactory.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

/**
FOUNDRY_PROFILE=oracles UNDERLYING_ORACLE=0x MARKET=0x \
    forge script silo-oracles/deploy/pendle/PendlePTOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract PendlePTOracleDeploy is CommonDeploy {
    ISiloOracle underlyingOracle;
    PendlePTOracleFactory factory;
    address market;
    bool qaMode;

    modifier withBroadcast() {
        if (!qaMode) {
            uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
            vm.startBroadcast(deployerPrivateKey);
        }

        _;

        if (!qaMode) vm.stopBroadcast();
    }

    function run() public withBroadcast returns (ISiloOracle oracle) {
        if (!qaMode) {
            AddrLib.init();

            factory =
                PendlePTOracleFactory(getDeployedAddress(SiloOraclesFactoriesContracts.PENDLE_PT_ORACLE_FACTORY));

            underlyingOracle = ISiloOracle(vm.envAddress("UNDERLYING_ORACLE"));
            market = AddrLib.getAddress(vm.envString("MARKET"));
        }


        oracle = factory.create({
            _underlyingOracle: underlyingOracle,
            _market: market
        });

        if (!qaMode) {
            string memory oracleName = string.concat("PENDLE_PT_ORACLE_", Strings.toHexString(market));
            OraclesDeployments.save(getChainAlias(), oracleName, address(oracle));
        }
    }

    function initQA(PendlePTOracleFactory _factory, address _market, ISiloOracle _underlyingOracle) external {
        factory = _factory;
        market = _market;
        underlyingOracle = _underlyingOracle;
        qaMode = true;
    }
}
