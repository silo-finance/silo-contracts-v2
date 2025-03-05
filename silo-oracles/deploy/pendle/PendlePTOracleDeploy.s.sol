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
    PendlePTOracleFactory factory;
    ISiloOracle underlyingOracle;
    address market;

    function run() public returns (ISiloOracle oracle) {
        AddrLib.init();

        if (address(factory) == address(0)) {
            factory =
                PendlePTOracleFactory(getDeployedAddress(SiloOraclesFactoriesContracts.PENDLE_PT_ORACLE_FACTORY));

            underlyingOracle = ISiloOracle(vm.envAddress("UNDERLYING_ORACLE"));
            market = vm.envAddress("MARKET");
        }

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        oracle = factory.create({
            _underlyingOracle: underlyingOracle,
            _market: market
        });

        vm.stopBroadcast();

        string memory oracleName = string.concat("PENDLE_PT_ORACLE_", Strings.toHexString(market));
        OraclesDeployments.save(getChainAlias(), oracleName, address(oracle));
    }

    function setParams(PendlePTOracleFactory _factory, address _market, ISiloOracle _underlyingOracle) external {
        factory = _factory;
        market = _market;
        underlyingOracle = _underlyingOracle;
    }
}
