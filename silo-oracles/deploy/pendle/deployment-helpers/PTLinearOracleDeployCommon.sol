// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {CommonDeploy} from "../../CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {PriceFormatter} from "silo-core/deploy/lib/PriceFormatter.sol";

import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

import {SiloOraclesFactoriesContracts, SiloOraclesFactoriesDeployments} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";
import {IPyYtLpOracleLike} from "silo-oracles/contracts/pendle/interfaces/IPyYtLpOracleLike.sol";
import {IPendleMarketV3Like} from "silo-oracles/contracts/pendle/interfaces/IPendleMarketV3Like.sol";
import {IPendleSYTokenLike} from "silo-oracles/contracts/pendle/interfaces/IPendleSYTokenLike.sol";
import {IPendlePTLike} from "silo-oracles/contracts/pendle/interfaces/IPendlePTLike.sol";
import {ISparkLinearDiscountOracleFactory} from "silo-oracles/contracts/pendle/interfaces/ISparkLinearDiscountOracleFactory.sol";

abstract contract PTLinearOracleDeployCommon is CommonDeploy {
    function _deployPTLinearOracle(
        address _pt, 
        uint256 _baseDiscountPerYear
    )
        internal 
        returns (AggregatorV3Interface oracle)
    {
        require(_pt != address(0), "pt is not set");
        require(_baseDiscountPerYear > 0 && _baseDiscountPerYear < 0.5e18, "baseDiscountPerYear looks invalid");

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory chainAlias = ChainsLib.chainAlias();

        ISparkLinearDiscountOracleFactory factory = ISparkLinearDiscountOracleFactory(
            AddrLib.getAddress(chainAlias, AddrKey.PENDLE_LINEAR_ORACLE_FACTORY)
        );

        console2.log("factory: ", address(factory));
        require(address(factory) != address(0), "factory is not set");

        vm.startBroadcast(deployerPrivateKey);
        oracle = AggregatorV3Interface(factory.createWithPt(_pt, _baseDiscountPerYear));
        vm.stopBroadcast();

        console2.log("--------------------------------");
        console2.log("deployed oracle, set this address to the json file:");
        console2.log(address(oracle));
        console2.log("--------------------------------");

        _verifyOracle(oracle, _pt);
    }

    function _verifyOracle(AggregatorV3Interface oracle, address _pt) internal {
        uint256 maturityDate = IPendlePTLike(_pt).expiry();
        uint256 currentTime = block.timestamp;

        require(_printPrice(oracle, "current") < 1e18);

        vm.warp(maturityDate - 1);
        require(_printPrice(oracle, "before maturity date") < 1e18, "before maturity date, price should be less than 1e18");

        vm.warp(maturityDate);
        require(_printPrice(oracle, "at maturity date") == 1e18, "after maturity date, price should be 1e18");

        vm.warp(maturityDate + 365 days);
        require(_printPrice(oracle, "after 1 year") == 1e18, "after 1 year, price should be 1e18");

        vm.warp(currentTime);
    }

    function _printPrice(AggregatorV3Interface oracle, string memory _description) 
        internal 
        view 
        returns (int256 price) 
    {
        (, price,,,) = oracle.latestRoundData();

        console2.log(
            string.concat("sample price for 1e18 PT (", _description, "):"), 
            PriceFormatter.formatPriceInE18(uint256(price))
        );
    }

    function _verifyMarket(
        address _market,
        address _ptToken,
        address _expectedUnderlyingToken
    ) 
        internal 
        view
    {
        require(_ptToken != address(0), "PT token is not set");
        require(_market != address(0), "Market is not set");
        require(_expectedUnderlyingToken != address(0), "Expected underlying token is not set");

        // Verify the PT token matches the market
        (address syToken, address ptToken, address ytToken) = IPendleMarketV3Like(_market).readTokens();
        require(ptToken == _ptToken, "PT token does not match market");

       (IPendleSYTokenLike.AssetType assetType, address assetAddress, uint8 assetDecimals) = IPendleSYTokenLike(syToken).assetInfo();

        console2.log("assetType:", assetType == IPendleSYTokenLike.AssetType.TOKEN ? "TOKEN" : "LIQUIDITY");
        console2.log("assetAddress:", assetAddress);
        console2.log("assetDecimals:", assetDecimals);
        console2.log("--------------------------------");

        require(assetType == IPendleSYTokenLike.AssetType.TOKEN, "assetType is not TOKEN");
        require(assetAddress == _expectedUnderlyingToken, "assetAddress must be our underlying token");

        console2.log("Pendle Market:", _market);
        console2.log("PT Token:", _ptToken);
        console2.log("SY Token:", syToken);
        console2.log("YT Token:", ytToken);
    }
}