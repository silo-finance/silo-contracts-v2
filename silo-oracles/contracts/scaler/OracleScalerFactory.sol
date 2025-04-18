// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {OracleScaler} from "silo-oracles/contracts/scaler/OracleScaler.sol";
import {IOracleScalerFactory} from "silo-oracles/contracts/interfaces/IOracleScalerFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

contract OracleScalerFactory is Create2Factory, IOracleScalerFactory {
    mapping(ISiloOracle => bool) public createdInFactory;

    /// @inheritdoc IOracleScalerFactory
    function createOracleScaler(
        address _quoteToken,
        bytes32 _externalSalt
    ) external virtual returns (ISiloOracle oracleScaler) {
        oracleScaler = new OracleScaler{salt: _salt(_externalSalt)}(_quoteToken);

        createdInFactory[oracleScaler] = true;

        emit OracleScalerCreated(oracleScaler);
    }
}
