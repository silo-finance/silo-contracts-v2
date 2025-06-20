// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {Utils} from "silo-core/deploy/silo/verifier/Utils.sol";

contract CheckExternalPrices is ICheck {
    address internal solvencyOracle0;
    address internal token0;
    uint256 internal externalPrice0;
    address internal solvencyOracle1;
    address internal token1;
    uint256 internal externalPrice1;

    uint256 internal contractsRatio;
    uint256 internal externalRatio;
    bool internal reverted;
    bool internal noExternalPrice;
    bool internal oracleReturnsZero;
    bool internal noOracleCase;
    bool internal wrongDecimalsForNoOracleCase;

    constructor(
        address _solvencyOracle0,
        address _token0,
        uint256 _externalPrice0,
        address _solvencyOracle1,
        address _token1,
        uint256 _externalPrice1
    ) {
        solvencyOracle0 = _solvencyOracle0;
        token0 = _token0;
        externalPrice0 = _externalPrice0;
        solvencyOracle1 = _solvencyOracle1;
        token1 = _token1;
        externalPrice1 = _externalPrice1;
        noOracleCase = _solvencyOracle0 == address(0) && _solvencyOracle1 == address(0);
    }

    function checkName() external pure override returns (string memory name) {
        name = "Difference of price1/price2 with external price source must be <1%";
    }

    function successMessage() external view override returns (string memory message) {
        if (noOracleCase) {
            message = "No oracles case: provided external prices are equal as expected";
        } else {
            message = string.concat(
                "Price1/Price2 from contracts ",
                Strings.toString(contractsRatio),
                " is close to external source ",
                Strings.toString(externalRatio)
            );
        }
    }

    function errorMessage() external view override returns (string memory message) {
        if (noExternalPrice) {
            message = "external price is not provided";
        } else if (reverted) {
            message = "oracles revert";
        } else if (oracleReturnsZero){
            message = "oracle returns zero";
        } else if (wrongDecimalsForNoOracleCase) {
            message = "no oracles case: decimals of tokens are not equal";
        } else if (noOracleCase) {
            message = "external prices are not equal for no oracles case, prices must be 1:1";
        } else {
           message = string.concat(
                "Price1/Price2 from contracts ",
                Strings.toString(contractsRatio),
                " is NOT close to external source ",
                Strings.toString(externalRatio)
            );
        }
    }

    function execute() external override returns (bool result) {
        return _checkExternalPrice();
    }

    function _checkExternalPrice() internal returns (bool success) {
        uint256 precisionDecimals = 10**18;

        uint256 token0Decimals = uint256(IERC20Metadata(token0).decimals());
        uint256 token1Decimals = uint256(IERC20Metadata(token1).decimals());
        uint256 oneToken0 = 10 ** token0Decimals;
        uint256 oneToken1 = 10 ** token1Decimals;

        if (externalPrice0 == 0 || externalPrice1 == 0) {
            noExternalPrice = true;
            return false;
        }

        if (noOracleCase) {
            if (token0Decimals != token1Decimals) {
                wrongDecimalsForNoOracleCase = true;
                return false;
            }

            return externalPrice0 == externalPrice1;
        }

        // price0 / price1 from external source
        externalRatio = externalPrice0 * precisionDecimals / externalPrice1;

        if (solvencyOracle1 == address(0)) {
            (, contractsRatio) = Utils.quote(ISiloOracle(solvencyOracle0), token0, oneToken0);
            contractsRatio = contractsRatio * precisionDecimals / oneToken1;
        } else {
            bool success0 = true;
            uint256 price0 = oneToken0;

            if (solvencyOracle0 != address(0)) {
                (success0, price0) = Utils.quote(ISiloOracle(solvencyOracle0), token0, oneToken0);
            }

            (bool success1, uint256 price1) =
                Utils.quote(ISiloOracle(solvencyOracle1), token1, oneToken1);

            if (!success0 || !success1) {
                reverted = true;
                return false;
            }

            if (price1 == 0) {
                oracleReturnsZero = true;
                return false;
            }

            contractsRatio = price0 * precisionDecimals / price1;
        }

        uint256 maxRatio = externalRatio > contractsRatio ? externalRatio : contractsRatio;
        uint256 minRatio = externalRatio > contractsRatio ? contractsRatio : externalRatio;

        uint256 ratioDiff = maxRatio - minRatio;

        if (minRatio == 0 || ratioDiff * precisionDecimals / maxRatio > precisionDecimals / 100) {
            return false;
        }

        success = true;
    }
}
