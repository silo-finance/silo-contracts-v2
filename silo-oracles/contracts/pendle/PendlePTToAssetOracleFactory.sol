// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {PendlePTToAssetOracle} from "silo-oracles/contracts/pendle/PendlePTToAssetOracle.sol";
import {IPendlePTOracleFactory} from "silo-oracles/contracts/interfaces/IPendlePTOracleFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPyYtLpOracleLike} from "silo-oracles/contracts/pendle/interfaces/IPyYtLpOracleLike.sol";

contract PendlePTToAssetOracleFactory is Create2Factory, IPendlePTOracleFactory {
    /// @dev Pendle oracle address.
    IPyYtLpOracleLike public immutable PENDLE_ORACLE; // solhint-disable-line var-name-mixedcase
    
    /// @dev Mapping of oracles created in this factory.
    mapping(ISiloOracle => bool) public createdInFactory;

    error PendleOracleIsZero();

    /// @dev Pendle oracle address is a single deployment per chain, it is equal for all markets. This address will
    /// be used to deploy PendlePTOracles.
    constructor(IPyYtLpOracleLike _pendleOracle) {
        require(address(_pendleOracle) != address(0), PendleOracleIsZero());
        PENDLE_ORACLE = _pendleOracle;
    }

    /// @inheritdoc IPendlePTOracleFactory
    function create(
        ISiloOracle _underlyingOracle,
        address _market,
        bytes32 _externalSalt
    ) external virtual returns (ISiloOracle pendlePTOracle) {
        pendlePTOracle = new PendlePTToAssetOracle{salt: _salt(_externalSalt)}({
            _underlyingOracle: _underlyingOracle,
            _pendleOracle: PENDLE_ORACLE,
            _market: _market
        });

        createdInFactory[pendlePTOracle] = true;
        emit PendlePTOracleCreated(pendlePTOracle);
    }
}
