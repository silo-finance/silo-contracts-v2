// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {Create2Factory} from "common/utils/Create2Factory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {ERC4626OracleHardcodeQuote} from "silo-oracles/contracts/erc4626/ERC4626OracleHardcodeQuote.sol";

import {
    IERC4626OracleHardcodeQuoteFactory
} from "silo-oracles/contracts/interfaces/IERC4626OracleHardcodeQuoteFactory.sol";

contract ERC4626OracleHardcodeQuoteFactory is Create2Factory, IERC4626OracleHardcodeQuoteFactory {
    mapping(address => bool) public createdInFactory;

    function createERC4626Oracle(
        IERC4626 _vault,
        address _quoteToken,
        bytes32 _externalSalt
    ) external returns (ISiloOracle oracle) {
        oracle = ISiloOracle(address(new ERC4626OracleHardcodeQuote{salt: _salt(_externalSalt)}(_vault, _quoteToken)));

        createdInFactory[address(oracle)] = true;

        emit ERC4626OracleCreated(oracle);
    }
}
