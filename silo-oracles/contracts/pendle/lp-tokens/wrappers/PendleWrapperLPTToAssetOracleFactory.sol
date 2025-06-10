// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPendleLPWrapperLike} from "silo-oracles/contracts/pendle/interfaces/IPendleLPWrapperLike.sol";

import {
    PendleWrapperLPTToAssetOracle
} from "silo-oracles/contracts/pendle/lp-tokens/wrappers/PendleWrapperLPTToAssetOracle.sol";

import {
    IPendleWrapperLPTToAssetOracleFactory
} from "silo-oracles/contracts/interfaces/IPendleWrapperLPTToAssetOracleFactory.sol";

contract PendleWrapperLPTToAssetOracleFactory is Create2Factory, IPendleWrapperLPTToAssetOracleFactory {
    /// @dev Mapping of oracles created in this factory.
    mapping(ISiloOracle => bool) public createdInFactory;

    /// @inheritdoc IPendleWrapperLPTToAssetOracleFactory
    function create(
        ISiloOracle _underlyingOracle,
        IPendleLPWrapperLike _wrapper,
        bytes32 _externalSalt
    ) external virtual returns (ISiloOracle pendleWrapperLPTOracle) {
        pendleWrapperLPTOracle = new PendleWrapperLPTToAssetOracle{salt: _salt(_externalSalt)}({
            _underlyingOracle: _underlyingOracle,
            _lptWrapper: _wrapper
        });

        createdInFactory[pendleWrapperLPTOracle] = true;
        emit PendleWrapperLPTToAssetOracleCreated(pendleWrapperLPTOracle);
    }
}
