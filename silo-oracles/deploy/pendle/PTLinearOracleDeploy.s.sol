// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {console2} from "forge-std/console2.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";
import {PriceFormatter} from "silo-core/deploy/lib/PriceFormatter.sol";
import {IPTLinearOracleFactory} from "silo-oracles/contracts/pendle/linear/PTLinearOracleFactory.sol";
import {IPTLinearOracle} from "silo-oracles/contracts/interfaces/IPTLinearOracle.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {IPendleSYTokenLike} from "silo-oracles/contracts/pendle/interfaces/IPendleSYTokenLike.sol";
import {IPendleMarketV3Like} from "silo-oracles/contracts/pendle/interfaces/IPendleMarketV3Like.sol";
import {IPendlePTLike} from "silo-oracles/contracts/pendle/interfaces/IPendlePTLike.sol";

/*
FOUNDRY_PROFILE=oracles \
PT_TOKEN=PT_thBILL_27NOV25 \
HARDCODED_QUOTE_TOKEN=USDC \
PT_MARKET=0x4ed09847377c30aa4e74ad071e719c5814ad9ead \
MAX_YIELD=0.25e18 \
    forge script silo-oracles/deploy/pendle/PTLinearOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_ARBITRUM --broadcast --verify
 */
contract PTLinearOracleDeploy is CommonDeploy {
    function run() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address factory = getDeployedAddress(SiloOraclesFactoriesContracts.PT_LINEAR_ORACLE_FACTORY);
        require(factory != address(0), string.concat("factory is not deployed: ", SiloOraclesFactoriesContracts.PT_LINEAR_ORACLE_FACTORY));

        IPTLinearOracleFactory.DeploymentConfig memory deploymentConfig = IPTLinearOracleFactory.DeploymentConfig({
            ptToken: AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("PT_TOKEN")),
            maxYield: vm.envUint("MAX_YIELD"),
            hardcodedQuoteToken: AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("HARDCODED_QUOTE_TOKEN"))
        });

        vm.startBroadcast(deployerPrivateKey);
        IPTLinearOracle oracle = IPTLinearOracleFactory(factory).create(deploymentConfig, bytes32(0));
        vm.stopBroadcast();

        string memory baseSymbol = IERC20Metadata(deploymentConfig.ptToken).symbol();
        string memory quoteSymbol = IERC20Metadata(deploymentConfig.hardcodedQuoteToken).symbol();

        string memory configName = string.concat("PT_LINEAR_ORACLE_", baseSymbol, "_", quoteSymbol);
    
        OraclesDeployments.save(getChainAlias(), configName, address(oracle));

        _qa(oracle, 10 ** IERC20Metadata(deploymentConfig.ptToken).decimals(), deploymentConfig.ptToken);
    }

    function _qa(IPTLinearOracle _oracle, uint256 _baseAmount, address _baseToken)
        internal
        returns (uint256 quote)
    {
        quote = _oracle.quote(_baseAmount, _baseToken);

        console2.log("\nQA ------------------------------: %s\n", address(_oracle));
        console2.log("    Base amount: ", PriceFormatter.formatPriceInE18(_baseAmount));
        console2.log("   %s Quote: %s", _oracle.description(), PriceFormatter.formatPriceInE18(quote));

        _verifyOracle(_oracle, _baseToken);

        _verifyMarket(vm.envAddress("PT_MARKET"), _baseToken, _oracle.quoteToken());
    }

    function _verifyOracle(IPTLinearOracle _oracle, address _pt) internal {
        uint256 maturityDate = IPendlePTLike(_pt).expiry();
        uint256 currentTime = block.timestamp;

        require(_printPrice(_oracle, "current") < 1e18);

        vm.warp(maturityDate - 1);
        require(
            _printPrice(_oracle, "before maturity date") < 1e18, "before maturity date, price should be less than 1e18"
        );

        vm.warp(maturityDate);
        require(_printPrice(_oracle, "at maturity date") == 1e18, "after maturity date, price should be 1e18");

        vm.warp(maturityDate + 365 days);
        require(_printPrice(_oracle, "after 1 year") == 1e18, "after 1 year, price should be 1e18");

        vm.warp(currentTime);
    }

    function _printPrice(IPTLinearOracle _oracle, string memory _description)
        internal
        view
        returns (int256 price)
    {
        (, price,,,) = _oracle.latestRoundData();

        console2.log(
            string.concat("sample price for 1e18 PT (", _description, "):"),
            PriceFormatter.formatPriceInE18(uint256(price))
        );
    }

    function _verifyMarket(address _market, address _ptToken, address _expectedUnderlyingToken) internal view {
        require(_ptToken != address(0), "PT token is not set");
        require(_market != address(0), "Market is not set");
        require(_expectedUnderlyingToken != address(0), "Expected underlying token is not set");

        // Verify the PT token matches the market
        (address syToken, address ptToken, address ytToken) = IPendleMarketV3Like(_market).readTokens();
        require(ptToken == _ptToken, "PT token does not match market");

        (IPendleSYTokenLike.AssetType assetType, address assetAddress, uint8 assetDecimals) =
            IPendleSYTokenLike(syToken).assetInfo();

        console2.log("assetType:", assetType == IPendleSYTokenLike.AssetType.TOKEN ? "TOKEN" : "LIQUIDITY");
        console2.log("assetAddress (%s): %s", IERC20Metadata(assetAddress).symbol(), assetAddress);
        console2.log("assetDecimals:", assetDecimals);
        console2.log("expectedUnderlyingToken:", _expectedUnderlyingToken);
        console2.log("--------------------------------");

        require(assetType == IPendleSYTokenLike.AssetType.TOKEN, "assetType is not TOKEN");
        require(assetAddress == _expectedUnderlyingToken, "PT asset must be our underlying token");

        console2.log("Pendle Market:", _market);
        console2.log("PT Token:", _ptToken);
        console2.log("SY Token:", syToken);
        console2.log("YT Token:", ytToken);
    }
}
