// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {PendleLPTToSyOracle} from "silo-oracles/contracts/pendle/lp-tokens/PendleLPTToSyOracle.sol";
import {IPendleLPTToSyOracleFactory} from "silo-oracles/contracts/interfaces/IPendleLPTToSyOracleFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

contract PendleLPTToSyOracleFactory is Create2Factory, IPendleLPTToSyOracleFactory {
    /// @dev Mapping of oracles created in this factory.
    mapping(ISiloOracle => bool) public createdInFactory;

    /// @inheritdoc IPendleLPTToSyOracleFactory
    function create(
        ISiloOracle _underlyingOracle,
        address _market,
        bytes32 _externalSalt
    ) external virtual returns (ISiloOracle pendleLPTOracle) {
        pendleLPTOracle = new PendleLPTToSyOracle{salt: _salt(_externalSalt)}({
            _underlyingOracle: _underlyingOracle,
            _market: _market
        });

        createdInFactory[pendleLPTOracle] = true;
        emit PendleLPTToSyOracleCreated(pendleLPTOracle);
    }
}
