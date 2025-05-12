// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {PendlePTOracleFactory} from "silo-oracles/contracts/pendle/PendlePTOracleFactory.sol";
import {PendlePTOracle} from "silo-oracles/contracts/pendle/PendlePTOracle.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {OraclesDeployments} from "silo-oracles/deploy/OraclesDeployments.sol"; 
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

/**
FOUNDRY_PROFILE=oracles UNDERLYING_ORACLE_NAME=PYTH_REDSTONE_wstkscETH_ETH MARKET=0xd14117baf6EC5D12BE68CD06e763A4B82C9B6d1D \
    forge script silo-oracles/deploy/pendle/PendlePTOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract PendlePTOracleDeploy is CommonDeploy {
    ISiloOracle underlyingOracle;
    address market;

    function run() public returns (ISiloOracle oracle) {
        PendlePTOracleFactory factory =
            PendlePTOracleFactory(getDeployedAddress(SiloOraclesFactoriesContracts.PENDLE_PT_ORACLE_FACTORY));

        string memory underlyingOracleName;

        if (address(market) == address(0)) {
            underlyingOracleName = vm.envString("UNDERLYING_ORACLE_NAME");
            market = vm.envAddress("MARKET");
            underlyingOracle = ISiloOracle(OraclesDeployments.get(ChainsLib.chainAlias(), underlyingOracleName));
        }

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        oracle = factory.create({
            _underlyingOracle: underlyingOracle,
            _market: market,
            _externalSalt: bytes32(0)
        });

        vm.stopBroadcast();

        IERC20Metadata ptToken = IERC20Metadata(PendlePTOracle(address(oracle)).PT_TOKEN()); 

        string memory oracleName = string.concat(
            "PENDLE_PT_ORACLE_",
            ptToken.symbol(),
            "_",
            underlyingOracleName
        );

        OraclesDeployments.save(getChainAlias(), oracleName, address(oracle));
    }

    function setParams(address _market, ISiloOracle _underlyingOracle) external {
        market = _market;
        underlyingOracle = _underlyingOracle;
    }
}
