// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {PendlePTOracle} from "silo-oracles/contracts/pendle/PendlePTOracle.sol";
import {IPendlePTOracleFactory} from "silo-oracles/contracts/interfaces/IPendlePTOracleFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPyYtLpOracleLike} from "silo-oracles/contracts/pendle/interfaces/IPyYtLpOracleLike.sol";

contract PendlePTOracleFactory is IPendlePTOracleFactory {
    /// @dev Pendle oracle address.
    IPyYtLpOracleLike public immutable PENDLE_ORACLE; // solhint-disable-line var-name-mixedcase
    
    /// @dev Mapping of oracles created in this factory.
    mapping(ISiloOracle => bool) public createdInFactory;

    /// @dev Pendle oracle address is a single deployment per chain, it is equal for all markets. This address will
    /// be used to deploy PendlePTOracles.
    constructor(IPyYtLpOracleLike _pendleOracle) {
        PENDLE_ORACLE = _pendleOracle;
    }

    /// @inheritdoc IPendlePTOracleFactory
    function create(
        ISiloOracle _underlyingOracle,
        address _ptToken,
        address _ptUnderlyingToken,
        address _market
    ) external virtual returns (ISiloOracle pendlePTOracle) {
        pendlePTOracle = new PendlePTOracle({
            _underlyingOracle: _underlyingOracle,
            _pendleOracle: PENDLE_ORACLE,
            _ptToken: _ptToken,
            _ptUnderlyingToken: _ptUnderlyingToken,
            _market: _market
        });

        createdInFactory[pendlePTOracle] = true;
        emit PendlePTOracleCreated(pendlePTOracle);
    }
}
