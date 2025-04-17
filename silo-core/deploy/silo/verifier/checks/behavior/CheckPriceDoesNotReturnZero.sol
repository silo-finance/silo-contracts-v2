// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

import {Utils} from "silo-core/deploy/silo/verifier/Utils.sol";

contract CheckPriceDoesNotReturnZero is ICheck {
    ISiloOracle internal oracle;
    string internal oracleName;
    address internal token;

    bool internal reverted;
    uint256 internal price;

    constructor(address _oracle, address _token, string memory _oracleName) {
        oracle = ISiloOracle(_oracle);
        token = _token;
        oracleName = _oracleName;
    }

    function checkName() external view override returns (string memory name) {
        name = string.concat(oracleName, " price > 0 when quote(0)");
    }

    function successMessage() external view override returns (string memory message) {
        if (reverted) {
            message = "quote(0) reverts";
        } else {
            message = string.concat("quote(0) = ", Strings.toString(price));
        }
    }

    function errorMessage() external pure override returns (string memory message) {
        message = "quote(0) = 0";
    }

    function execute() external override returns (bool result) {
        bool success;
        (success, price) = Utils.quote(oracle, token, 0);

        reverted = !success;

        if (reverted) {
            return true;
        }

        return price != 0;
    }
}
