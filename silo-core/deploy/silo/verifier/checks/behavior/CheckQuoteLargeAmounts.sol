// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {Utils} from "silo-core/deploy/silo/verifier/Utils.sol";

contract CheckQuoteLargeAmounts is ICheck {
    ISiloOracle internal oracle;
    string internal oracleName;
    address internal token;
    uint256 internal toQuote;

    uint256 internal price;

    constructor(address _oracle, address _token, string memory _oracleName) {
        oracle = ISiloOracle(_oracle);
        token = _token;
        oracleName = _oracleName;

        toQuote = 10**36 + 10**20 * (10**uint256(Utils.tryGetTokenDecimals(_token)));
    }

    function checkName() external view override returns (string memory name) {
        name = string.concat(
            oracleName,
            " quote must not revert for large amounts quote(10**36 wei + 10**20 tokens in own decimals)"
        );
    }

    function successMessage() external pure override returns (string memory message) {
        message = "oracle does not revert";
    }

    function errorMessage() external pure override returns (string memory message) {
        message = "oracle reverts";
    }

    function execute() external override returns (bool result) {
        bool success;
        (success, price) = Utils.quote(oracle, token, toQuote);
        return success;
    }
}
