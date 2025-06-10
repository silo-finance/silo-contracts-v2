// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts, SiloOraclesFactoriesDeployments} from "../SiloOraclesFactoriesContracts.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {PendleLPTToAssetOracleFactory} from "silo-oracles/contracts/pendle/lp-tokens/PendleLPTToAssetOracleFactory.sol";
import {PendleLPTToAssetOracle} from "silo-oracles/contracts/pendle/lp-tokens/PendleLPTToAssetOracle.sol";
import {OraclesDeployments} from "silo-oracles/deploy/OraclesDeployments.sol";
import {IPendleMarketV3Like} from "silo-oracles/contracts/pendle/interfaces/IPendleMarketV3Like.sol";

/**
FOUNDRY_PROFILE=oracles UNDERLYING_ORACLE_NAME=PYTH_REDSTONE_wstkscETH_ETH MARKET=0xd14117baf6EC5D12BE68CD06e763A4B82C9B6d1D \
    forge script silo-oracles/deploy/pendle/PendleLPTToAssetOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract PendleLPTToAssetOracleDeploy is CommonDeploy {
    ISiloOracle underlyingOracle;
    address market;

    function run() public returns (ISiloOracle oracle) {
        string memory chainAlias = ChainsLib.chainAlias();

        PendleLPTToAssetOracleFactory factory = PendleLPTToAssetOracleFactory(SiloOraclesFactoriesDeployments.get(
            SiloOraclesFactoriesContracts.PENDLE_LPT_TO_ASSET_ORACLE_FACTORY,
            chainAlias
        ));

        string memory underlyingOracleName;

        if (address(market) == address(0)) {
            underlyingOracleName = vm.envString("UNDERLYING_ORACLE_NAME");
            market = vm.envAddress("MARKET");
            underlyingOracle = ISiloOracle(OraclesDeployments.get(chainAlias, underlyingOracleName));
        }

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        oracle = factory.create({
            _underlyingOracle: underlyingOracle,
            _market: market,
            _externalSalt: bytes32(0)
        });

        vm.stopBroadcast();

        (address syToken,,) = IPendleMarketV3Like(market).readTokens();

        string memory oracleName = string.concat(
            "PENDLE_LPT_TO_ASSET_ORACLE_",
            IERC20Metadata(syToken).symbol(),
            "_",
            underlyingOracleName
        );

        OraclesDeployments.save(chainAlias, oracleName, address(oracle));
    }

    function setParams(address _market, ISiloOracle _underlyingOracle) external {
        market = _market;
        underlyingOracle = _underlyingOracle;
    }
}
