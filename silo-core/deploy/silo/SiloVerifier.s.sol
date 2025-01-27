// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

/**
FOUNDRY_PROFILE=core CONFIG=0xC1F3d4F5f734d6Dc9E7D4f639EbE489Acd4542ab \
    forge script silo-core/deploy/silo/SiloVerifier.s.sol \
    --ffi --rpc-url $RPC_SONIC
 */

contract SiloVerifier is Script, Test {
    // used to generate quote amounts and names to log
    struct QuoteNamedAmount {
        uint256 amount;
        string name;
    }

    string constant internal _SUCCESS_SYMBOL = unicode"✅";
    string constant internal _FAIL_SYMBOL = unicode"❌";

    function run() public {
        ISiloConfig siloConfig = ISiloConfig(vm.envAddress("CONFIG"));
        uint256 errorsCounter = _checkConfig(siloConfig);
        
        if (errorsCounter == 0) {
            console2.log(_SUCCESS_SYMBOL, "Config checks are done with 0 errors");
        } else {
            console2.log("%s Config checks are done with %s errors", _FAIL_SYMBOL, errorsCounter);
        }
    }

    // returns total amount of errors for SiloConfig address
    function _checkConfig(ISiloConfig _siloConfig) internal returns (uint256 errorsCounter) {
        (address silo0, address silo1) = _siloConfig.getSilos();

        errorsCounter += _checkSilo(_siloConfig, silo0);
        errorsCounter += _checkSilo(_siloConfig, silo1);
    }

    // returns total amount of errors for Silo address
    function _checkSilo(ISiloConfig _siloConfig, address _silo) internal returns (uint256 errorsCounter) {
        emit log_named_address("\nsiloConfig", address(_siloConfig));

        ISiloConfig.ConfigData memory configData = ISiloConfig(_siloConfig).getConfig(_silo);

        (address silo0,) = _siloConfig.getSilos();

        emit log_string(_silo == silo0 ? "silo0" : "silo1");
        emit log_named_address("silo", _silo);
        emit log_named_address("token", configData.token);
        emit log_named_string("symbol", IERC20Metadata(configData.token).symbol());
        emit log_named_uint("decimals", IERC20Metadata(configData.token).decimals());

        // print the config data
        emit log_named_decimal_uint("daoFee", configData.daoFee, 18);
        emit log_named_decimal_uint("deployerFee", configData.deployerFee, 18);
        emit log_named_decimal_uint("liquidationFee", configData.liquidationFee, 18);
        emit log_named_decimal_uint("flashloanFee", configData.flashloanFee, 18);
        emit log_named_decimal_uint("maxLtv", configData.maxLtv, 18);
        emit log_named_decimal_uint("lt", configData.lt, 18);
        emit log_named_decimal_uint("liquidationTargetLtv", configData.liquidationTargetLtv, 18);
        emit log_named_address("solvencyOracle", configData.solvencyOracle);
        emit log_named_address("maxLtvOracle", configData.maxLtvOracle);

        if (configData.solvencyOracle != address(0)) {
            errorsCounter += _checkOracle(ISiloOracle(configData.solvencyOracle), configData.token);
        }

        if (configData.maxLtvOracle != configData.solvencyOracle && configData.maxLtvOracle != address(0)) {
            errorsCounter += _checkOracle(ISiloOracle(configData.maxLtvOracle), configData.token);
        }

        errorsCounter += _sanityCheckConfig(configData);
    }

    // returns total amount of errors for numbers in ConfigData
    function _sanityCheckConfig(ISiloConfig.ConfigData memory _configData) internal pure returns (uint256 errorsCounter) {
        uint256 onePercent = 10**18 / 100;

        if (_configData.daoFee > onePercent * 25 || _configData.daoFee < onePercent / 100) {
            errorsCounter++;
            console2.log(_FAIL_SYMBOL, "daoFee >25% or <0.01%");
        }

        if (_configData.deployerFee != 0) {
            errorsCounter++;
            console2.log(_FAIL_SYMBOL, "deployerFee != 0");
        }

        if (_configData.liquidationFee < onePercent / 100 || _configData.liquidationFee > onePercent * 15) {
            errorsCounter++;
            console2.log(_FAIL_SYMBOL, "liquidationFee >15% or <0.01%");
        }

        if (_configData.flashloanFee > onePercent) {
            errorsCounter++;
            console2.log(_FAIL_SYMBOL, "flashloanFee >1%");
        }
    }

    // returns the total amount of errors for specific oracle
    function _checkOracle(ISiloOracle _oracle, address _baseToken) internal view returns (uint256 errorsCounter) {
        address quoteToken = _oracle.quoteToken();
        uint256 quoteTokenDecimals = IERC20Metadata(quoteToken).decimals();

        console2.log("\nOracle:", address(_oracle));
        console2.log("Token name:", IERC20Metadata(_baseToken).name());
        console2.log("Token symbol:", IERC20Metadata(_baseToken).symbol());
        console2.log("Token decimals:", IERC20Metadata(_baseToken).decimals());
        console2.log("Quote token name:", _tryGetTokenName(IERC20Metadata(quoteToken)));
        console2.log("Quote token symbol:", _tryGetTokenSymbol(IERC20Metadata(quoteToken)));
        console2.log("Quote token decimals:", quoteTokenDecimals);
        console2.log("Quote token:", quoteToken);

        (QuoteNamedAmount[] memory amountsToQuote) = _getAmountsToQuote(IERC20Metadata(_baseToken).decimals());

        for (uint i; i < amountsToQuote.length; i++) {
            errorsCounter += _printPrice(_oracle, _baseToken, amountsToQuote[i]);
        }

        errorsCounter += _priceSanityChecks(_oracle, _baseToken);
    }

    function _getAmountsToQuote(uint8 _baseTokenDecimals) internal pure returns (QuoteNamedAmount[] memory amountsToQuote) {
        amountsToQuote = new QuoteNamedAmount[](9);
        uint256 oneToken = (10 ** uint256(_baseTokenDecimals));

        amountsToQuote[0] = QuoteNamedAmount({
            amount: 1,
            name: "1 wei (lowest amount)"
        });

        amountsToQuote[1] = QuoteNamedAmount({
            amount: 10,
            name: "10 wei"
        });

        amountsToQuote[2] = QuoteNamedAmount({
            amount: oneToken / 10,
            name: "0.1 token"
        });

        amountsToQuote[3] = QuoteNamedAmount({
            amount: oneToken / 2,
            name: "0.5 token"
        });

        amountsToQuote[4] = QuoteNamedAmount({
            amount: oneToken,
            name: "1 token (10 ^ decimals)"
        });

        amountsToQuote[5] = QuoteNamedAmount({
            amount: 100 * oneToken,
            name: "100 tokens"
        });

        amountsToQuote[6] = QuoteNamedAmount({
            amount: 10_000 * oneToken,
            name: "10,000 tokens"
        });

        amountsToQuote[7] = QuoteNamedAmount({
            amount: 10**36,
            name: "10**36 wei"
        });

        amountsToQuote[8] = QuoteNamedAmount({
            amount: 10**20 * oneToken,
            name: "10**20 tokens (More than USA GDP if the token worth at least 0.001 cent)"
        });
    }

    function _priceSanityChecks(ISiloOracle _oracle, address _baseToken) internal view returns (uint256 errorsCounter) {
        (bool success, uint256 price) = _quote(_oracle, _baseToken, 1);

        if (!success || price == 0) {
            console2.log(_FAIL_SYMBOL, "quote (1 wei) reverts or zero");
            errorsCounter++;
        } else {
            console2.log(_SUCCESS_SYMBOL, "quote (1 wei) is not zero");
        }

        uint256 largestAmount = 10**36 + 10**20 * (10**uint256(IERC20Metadata(_baseToken).decimals()));
        (success, price) = _quote(_oracle, _baseToken, largestAmount);

        if (!success) {
            console2.log("%s quote (%e) reverts", _FAIL_SYMBOL, largestAmount);
            errorsCounter++;
        } else {
            console2.log("%s quote (%e) do not revert", _SUCCESS_SYMBOL, largestAmount);
        }
    }

    function _printPrice(ISiloOracle _oracle, address _baseToken, QuoteNamedAmount memory _quoteNamedAmount)
        internal
        view
        returns (uint256 errorsCounter)
    {
        (bool success, uint256 price) = _quote(_oracle, _baseToken, _quoteNamedAmount.amount);

        if (success) {
            console2.log("Price for %s = %e", _quoteNamedAmount.name, price);
        } else {
            console2.log(_FAIL_SYMBOL, "Price for:", _quoteNamedAmount.name, "REVERT!");
            errorsCounter++;
        }
    }

    function _quote(ISiloOracle _oracle, address _baseToken, uint256 _amount)
        internal
        view
        returns (bool success, uint256 price)
    {
        try _oracle.quote(_amount, _baseToken) returns (uint256 priceFromOracle) {
            success = true;
            price = priceFromOracle;
        } catch {
            success = false;
            price = 0;
        }
    }

    function _tryGetTokenSymbol(IERC20Metadata _token) internal view returns (string memory) {
        try _token.symbol() returns (string memory symbol) {
            return symbol;
        } catch {
            return "Symbol reverted";
        }
    }

    function _tryGetTokenName(IERC20Metadata _token) internal view returns (string memory) {
        try _token.name() returns (string memory name) {
            return name;
        } catch {
            return "Name reverted";
        }
    }
}
