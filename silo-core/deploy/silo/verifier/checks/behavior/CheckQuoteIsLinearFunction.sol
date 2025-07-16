// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;
import {console2} from "forge-std/console2.sol";

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {Strings} from "openzeppelin5/utils/Strings.sol";
import {Utils} from "silo-core/deploy/silo/verifier/Utils.sol";
import {PriceFormatter} from "../../../../lib/PriceFormatter.sol";

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
        message = string.concat(
            "property does not hold, breaks at amount ",
            PriceFormatter.formatNumberInE(breaksAtAmount)
        );
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

            /*
            if we just div by 10, lower price might have some rounding applied eg.
            previousQuote 98495855921412629816832503143859_353
             currentQuote 98495855921412629816832503143859_34 < we can expect rounding down from 35 -> 34

             previousQuote 9849591762903238198737336703_9006
              currentQuote 9849591762903238198737336703_899

             to handle this case, we need to divide both prices by additional number, to combat any expected rounding
            */
            if (currentQuote != previousQuote / 10) {
                console2.log("previousQuote", previousQuote);
                console2.log(" currentQuote", currentQuote);

                (, currentQuote) = Utils.quote(oracle, token, 1e18);
                console2.log("quote(1e18)", currentQuote);
                (, currentQuote) = Utils.quote(oracle, token, 1e17);
                console2.log("quote(1e17)", currentQuote);

                breaksAtAmount = amountToQuote;
                return false;
            }

            previousQuote = currentQuote;
        }

        return true;
    }
}
