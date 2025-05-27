// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {PendleLPTOracle} from "silo-oracles/contracts/pendle/PendleLPTOracle.sol";
import {IPendleLPTOracleFactory} from "silo-oracles/contracts/interfaces/IPendleLPTOracleFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPendleOracleHelper} from "silo-oracles/contracts/pendle/interfaces/IPendleOracleHelper.sol";

contract PendleLPTOracleFactory is Create2Factory, IPendleLPTOracleFactory {
    /// @dev Mapping of oracles created in this factory.
    mapping(ISiloOracle => bool) public createdInFactory;

    /// @inheritdoc IPendleLPTOracleFactory
    function create(
        ISiloOracle _underlyingOracle,
        address _market,
        bytes32 _externalSalt
    ) external virtual returns (ISiloOracle pendleLPTOracle) {
        pendleLPTOracle = new PendleLPTOracle{salt: _salt(_externalSalt)}({
            _underlyingOracle: _underlyingOracle,
            _market: _market
        });

        createdInFactory[pendleLPTOracle] = true;
        emit PendleLPTOracleCreated(pendleLPTOracle);
    }
}
