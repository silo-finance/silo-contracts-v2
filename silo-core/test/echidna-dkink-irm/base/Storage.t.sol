// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";
import {DynamicKinkModelFactory} from "silo-core/contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";
import {SiloDKinkMock} from "silo-core/test/echidna-dkink-irm/mocks/SiloDKinkMock.sol";

/// @notice Storage contract for DynamicKinkModel test contracts
/// @dev Stores all state variables and constants used across test contracts
abstract contract Storage {
    struct State {
        IDynamicKinkModel.Config config;
        int232 u;
        int256 k;
        uint256 collateralAssets;
        uint256 debtAssets;
        uint256 interestRateTimestamp;
        uint256 blockTimestamp;
        uint256 rcur;
        uint256 rcomp;
        bool initialized;
    }

    uint256 internal constant _DP = 1e18;
    uint256 internal constant _RCUR_CAP = 50 * _DP;
    uint256 internal constant _ONE_YEAR = 365 days;
    uint256 internal constant _RCOMP_CAP = _RCUR_CAP / _ONE_YEAR;
    uint256 internal constant _UNIVERSAL_LIMIT = 1e9 * _DP;
    int256 internal constant _UNIVERSAL_LIMIT_WITH_ERROR = int256(_UNIVERSAL_LIMIT) + 1e6;
    int256 internal constant _DP_WITH_ERROR = int256(_DP) + 1e6;

    DynamicKinkModelFactory internal _factory;
    IDynamicKinkModel internal _irm;
    SiloDKinkMock internal _siloMock;

    State internal _stateBefore;
    State internal _stateAfter;

    bool internal _setupConfigWithNonZeroValues;
}
