// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPendleLPWrapperLike} from "silo-oracles/contracts/pendle/interfaces/IPendleLPWrapperLike.sol";

import {
    PendleWrapperLPTToSyOracle
} from "silo-oracles/contracts/pendle/lp-tokens/wrappers/PendleWrapperLPTToSyOracle.sol";

import {
    IPendleWrapperLPTToSyOracleFactory
} from "silo-oracles/contracts/interfaces/IPendleWrapperLPTToSyOracleFactory.sol";

contract PendleWrapperLPTToSyOracleFactory is Create2Factory, IPendleWrapperLPTToSyOracleFactory {
    /// @dev Mapping of oracles created in this factory.
    mapping(ISiloOracle => bool) public createdInFactory;

    /// @inheritdoc IPendleWrapperLPTToSyOracleFactory
    function create(
        ISiloOracle _underlyingOracle,
        IPendleLPWrapperLike _wrapper,
        bytes32 _externalSalt
    ) external virtual returns (ISiloOracle pendleWrapperLPTToSyOracle) {
        pendleWrapperLPTToSyOracle = new PendleWrapperLPTToSyOracle{salt: _salt(_externalSalt)}({
            _underlyingOracle: _underlyingOracle,
            _lptWrapper: _wrapper
        });

        createdInFactory[pendleWrapperLPTToSyOracle] = true;
        emit PendleWrapperLPTToSyOracleCreated(pendleWrapperLPTToSyOracle);
    }
}
