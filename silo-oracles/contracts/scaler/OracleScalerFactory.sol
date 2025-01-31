// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {OracleScaler} from "silo-oracles/contracts/scaler/OracleScaler.sol";
import {IOracleScalerFactory} from "silo-oracles/contracts/interfaces/IOracleScalerFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IOracleScaler} from "silo-oracles/contracts/interfaces/IOracleScaler.sol";

contract OracleScalerFactory is IOracleScalerFactory {
    mapping(address => bool) public createdInFactory;

    /// @inheritdoc IOracleScalerFactory
    function createOracleScaler(
        IERC20Metadata _quoteToken
    ) external returns (ISiloOracle oracleScaler) {
        oracleScaler = new OracleScaler(_quoteToken);

        createdInFactory[address(OracleScaler)] = true;

        emit OracleScalerCreated(address(OracleScaler));
    }
}
