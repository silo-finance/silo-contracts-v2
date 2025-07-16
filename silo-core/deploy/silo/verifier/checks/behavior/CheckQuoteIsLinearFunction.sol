// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

import {Utils} from "silo-core/deploy/silo/verifier/Utils.sol";

contract CheckQuoteIsLinearFunction is ICheck {
    ISiloOracle internal oracle;
    string internal oracleName;
    address internal token;

    bool internal reverted;
    uint256 breaksAtAmount;

    constructor(address _oracle, address _token, string memory _oracleName) {
        oracle = ISiloOracle(_oracle);
        token = _token;
        oracleName = _oracleName;
    }

    function checkName() external view override returns (string memory name) {
        name = string.concat(oracleName, " quote is a linear function (quote(10x) = 10*quote(x))");
    }

    function successMessage() external view override returns (string memory message) {
        if (reverted) {
            message = "quote() reverted during linear function check";
        } else {
            message = "property holds";
        }
    }

    function errorMessage() external view override returns (string memory message) {
        message = string.concat("property does not hold, breaks at amount ", Strings.toString(breaksAtAmount));
    }

    function execute() external override returns (bool result) {
        uint256 previousQuote = type(uint256).max;
        uint256 maxAmountToQuote = 10**36;
        bool success;

        for (uint amountToQuote = maxAmountToQuote; amountToQuote >= 100; amountToQuote /= 10) {
            // init previous quote with the first element
            if (previousQuote == type(uint256).max) {
                (success, previousQuote) = Utils.quote(oracle, token, amountToQuote);

                if (!success) {
                    reverted = true;
                    return true;
                }

                continue;
            }

            // check linear property
            uint256 currentQuote;
            (success, currentQuote) = Utils.quote(oracle, token, amountToQuote);

            if (currentQuote != previousQuote / 10) {
                breaksAtAmount = amountToQuote;
                return false;
            }

            previousQuote = currentQuote;
        }

        return true;
    }
}
