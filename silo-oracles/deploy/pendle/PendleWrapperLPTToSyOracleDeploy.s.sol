// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts, SiloOraclesFactoriesDeployments} from "../SiloOraclesFactoriesContracts.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {PendleWrapperLPTToSyOracleFactory} from "silo-oracles/contracts/pendle/lp-tokens/wrappers/PendleWrapperLPTToSyOracleFactory.sol";
import {PendleWrapperLPTToSyOracle} from "silo-oracles/contracts/pendle/lp-tokens/wrappers/PendleWrapperLPTToSyOracle.sol";
import {OraclesDeployments} from "silo-oracles/deploy/OraclesDeployments.sol";
import {IPendleMarketV3Like} from "silo-oracles/contracts/pendle/interfaces/IPendleMarketV3Like.sol";
import {IPendleLPWrapperLike} from "silo-oracles/contracts/pendle/interfaces/IPendleLPWrapperLike.sol";

/**
FOUNDRY_PROFILE=oracles UNDERLYING_ORACLE_NAME=CHAINLINK_sUSDe_USD LPT_WRAPPER=0xaB025d7b57B0902A2797599F3eB07477400e62B0 \
    forge script silo-oracles/deploy/pendle/PendleWrapperLPTToSyOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_MAINNET --broadcast --verify
 */
contract PendleWrapperLPTToSyOracleDeploy is CommonDeploy {
    ISiloOracle underlyingOracle;
    address lptWrapper;

    function run() public returns (ISiloOracle oracle) {
        string memory chainAlias = ChainsLib.chainAlias();

        PendleWrapperLPTToSyOracleFactory factory = PendleWrapperLPTToSyOracleFactory(SiloOraclesFactoriesDeployments.get(
            SiloOraclesFactoriesContracts.PENDLE_WRAPPER_LPT_TO_SY_ORACLE_FACTORY,
            chainAlias
        ));

        string memory underlyingOracleName;

        if (address(lptWrapper) == address(0)) {
            underlyingOracleName = vm.envString("UNDERLYING_ORACLE_NAME");
            lptWrapper = vm.envAddress("LPT_WRAPPER");
            underlyingOracle = ISiloOracle(OraclesDeployments.get(chainAlias, underlyingOracleName));
        }

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        oracle = factory.create({
            _underlyingOracle: underlyingOracle,
            _wrapper: IPendleLPWrapperLike(lptWrapper),
            _externalSalt: bytes32(0)
        });

        vm.stopBroadcast();

        address market = IPendleLPWrapperLike(lptWrapper).LP();
        (, address ptToken,) = IPendleMarketV3Like(market).readTokens();

        string memory oracleName = string.concat(
            "PENDLE_WRAPPER_LPT_ORACLE_",
            IERC20Metadata(ptToken).symbol(),
            "_",
            underlyingOracleName
        );

        OraclesDeployments.save(chainAlias, oracleName, address(oracle));
    }

    function setParams(address _wrapper, ISiloOracle _underlyingOracle) external {
        lptWrapper = _wrapper;
        underlyingOracle = _underlyingOracle;
    }
}
