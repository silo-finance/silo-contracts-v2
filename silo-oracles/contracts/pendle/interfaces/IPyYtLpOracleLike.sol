// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

interface IPyYtLpOracleLike {
    function getPtToSyRate(address market, uint32 duration) external view returns (uint256);
    function getPtToAssetRate(address market, uint32 duration) external view returns (uint256);

    function getOracleState(
        address market,
        uint32 duration
    )
        external
        view
        returns (
            bool increaseCardinalityRequired,
            uint16 cardinalityRequired,
            bool oldestObservationSatisfied
        );
}
