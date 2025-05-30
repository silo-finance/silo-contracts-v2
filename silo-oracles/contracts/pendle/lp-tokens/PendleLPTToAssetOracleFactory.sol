// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {PendleLPTToAssetOracle} from "silo-oracles/contracts/pendle/lp-tokens/PendleLPTToAssetOracle.sol";
import {IPendleLPTToAssetOracleFactory} from "silo-oracles/contracts/interfaces/IPendleLPTToAssetOracleFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

contract PendleLPTToAssetOracleFactory is Create2Factory, IPendleLPTToAssetOracleFactory {
    /// @dev Mapping of oracles created in this factory.
    mapping(ISiloOracle => bool) public createdInFactory;

    /// @inheritdoc IPendleLPTToAssetOracleFactory
    function create(
        ISiloOracle _underlyingOracle,
        address _market,
        bytes32 _externalSalt
    ) external virtual returns (ISiloOracle pendleLPTOracle) {
        pendleLPTOracle = new PendleLPTToAssetOracle{salt: _salt(_externalSalt)}({
            _underlyingOracle: _underlyingOracle,
            _market: _market
        });

        createdInFactory[pendleLPTOracle] = true;
        emit PendleLPTToAssetOracleCreated(pendleLPTOracle);
    }
}
