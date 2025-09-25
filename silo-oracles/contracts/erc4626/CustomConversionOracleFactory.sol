// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {CustomConversionOracle} from "./CustomConversionOracle.sol";

contract CustomConversionOracleFactory is Create2Factory {
    event OracleCreated(ISiloOracle indexed oracle, address indexed vault);

    mapping(address => bool) public createdByFactory;

    function create(
        address _vault,
        string memory _conversionFunction,
        address _quoteToken,
        bytes32 _externalSalt
    ) external returns (ISiloOracle oracle) {
        oracle = ISiloOracle(address(new CustomConversionOracle{salt: _salt(_externalSalt)}(_vault, _conversionFunction, _quoteToken)));

        createdByFactory[address(oracle)] = true;

        emit OracleCreated(oracle, _vault);
    }
}
