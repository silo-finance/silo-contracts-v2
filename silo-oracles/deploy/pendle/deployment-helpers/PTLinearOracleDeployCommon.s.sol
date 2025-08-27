// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {CommonDeploy} from "../../CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

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

        console2.log("deployed oracle, set this address to the json file\n%s\n--------------------------------", address(oracle));

        _printPrice(oracle, "current") ;

        _verifyOracle(oracle, _pt);
    }

    function _pullExchangeFactor(AggregatorV3Interface oracle, address _market, address _ptToken) 
        internal 
        view
        returns (uint256 exchangeFactor) 
    {
        uint32 duration = 30 minutes; // Default TWAP duration
        
        exchangeFactor = _pullExchangeFactorForUnderlying(_ptToken, _market, duration);

        _printExpectedPrice(oracle, exchangeFactor);
    }

    function _verifyOracle(AggregatorV3Interface oracle, address _pt) internal {
        uint256 maturityDate = IPendlePTLike(_pt).expiry();
        uint256 currentTime = block.timestamp;

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
        console2.log(string.concat("sample price for 1e18 PT (", _description, "):"), price);
    }

    /// @notice Pulls the exchange factor for the underlying token from Pendle market
    /// @param _ptToken The PT token address (0x936F210d277bf489A3211CeF9AB4BC47a7B69C96 for pt_sUSDai_19NOV25)
    /// @param _market The Pendle market address
    /// @param _duration TWAP duration in seconds (default 30 minutes)
    /// @return exchangeFactor The exchange factor (PtToSyRate) for the underlying token
    function _pullExchangeFactorForUnderlying(
        address _ptToken,
        address _market,
        uint32 _duration
    ) 
        internal 
        view 
        returns (uint256 exchangeFactor) 
    {
        require(_ptToken != address(0), "PT token is not set");
        require(_market != address(0), "Market is not set");
        require(_duration > 0, "Duration must be greater than 0");

        string memory chainAlias = ChainsLib.chainAlias();

        // // Get the Pendle oracle address (this is the same for all networks)
        // IPyYtLpOracleLike pendleOracle = IPyYtLpOracleLike(AddrLib.getAddress(chainAlias, AddrKey.PENDLE_ORACLE));
        // console2.log("pendleOracle: ", address(pendleOracle));

        // Verify the PT token matches the market
        IPendleMarketV3Like marketContract = IPendleMarketV3Like(_market);
        (address syToken, address ptToken, address ytToken) = marketContract.readTokens();
        require(ptToken == _ptToken, "PT token does not match market");

        // Get the exchange factor (PtToSyRate)
        // exchangeFactor = pendleOracle.getPtToSyRate(_market, _duration);
        uint256 exchangeFactor = IPendleSYTokenLike(syToken).exchangeRate();
        (IPendleSYTokenLike.AssetType assetType, address assetAddress, uint8 assetDecimals) = IPendleSYTokenLike(syToken).assetInfo();

        console2.log("assetType:", assetType == IPendleSYTokenLike.AssetType.TOKEN ? "TOKEN" : "LIQUIDITY");
        console2.log("assetAddress:", assetAddress);
        console2.log("assetDecimals:", assetDecimals);
        console2.log("--------------------------------");

        require(assetType == IPendleSYTokenLike.AssetType.TOKEN, "assetType is not TOKEN");
        require(assetAddress == _ptToken, "assetAddress must be our underlying token");

        console2.log("Pendle Market:", _market);
        console2.log("PT Token:", _ptToken);
        console2.log("SY Token:", syToken);
        console2.log("YT Token:", ytToken);
        console2.log("Exchange Factor (PtToSyRate), use it for factor for linear oracle?:", exchangeFactor);
        console2.log("TWAP Duration:", _duration, "seconds");

        return exchangeFactor;
    }

    function _printExpectedPrice(AggregatorV3Interface oracle, uint256 _exchangeFactor) internal view {
        (, int256 price,,,) = oracle.latestRoundData();
        console2.log("--------------------------------");
        console2.log("Expected price for 1e18 PT:", uint256(price) * _exchangeFactor / 1e18);
        console2.log("--------------------------------");
    }
}
