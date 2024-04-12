// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IInterestRateModelV2Config} from "./IInterestRateModelV2Config.sol";

// solhint-disable var-name-mixedcase

interface IDynamicKinkModelV1 {
    struct Config {
        // uopt ∈ (0, 1) – optimal utilization;
        int256 uopt;
        // ucrit ∈ (uopt, 1) – threshold of large utilization;
        int256 ucrit;
        // ulow ∈ (0, uopt) – threshold of low utilization
        int256 ulow;
        // rmin ≥ 0 minimal per-second interest rate
        int256 rmin;
        // kmin ≥ 0 minimal slope of central segment of the kink
        int256 kmin;
        // kmax ≥ kmin max slope of central segment of the kink
        int256 kmax;
        // alpha ≥ 0 factor for the slope for the critical segment of the kink
        int256 alpha;
        // cplus ≥ 0 coefficent of growth of the slope k
        int256 cplus;
        // cminus ≥ 0 coefficent of decrease of the slope k
        int256 cminus;
        // c0 ≥ 0 minimal rate of decrease of the slope k
        int256 c0;
    }

    struct ConfigWithState {
         // uopt ∈ (0, 1) – optimal utilization;
        int256 uopt;
        // ucrit ∈ (uopt, 1) – threshold of large utilization;
        int256 ucrit;
        // ulow ∈ (0, uopt) – threshold of low utilization
        int256 ulow;
        // rmin ≥ 0 minimal per-second interest rate
        int256 rmin;
        // kmin ≥ 0 minimal slope of central segment of the kink
        int256 kmin;
        // kmax ≥ kmin max slope of central segment of the kink
        int256 kmax;
        // alpha ≥ 0 factor for the slope for the critical segment of the kink
        int256 alpha;
        // cplus ≥ 0 coefficent of growth of the slope k
        int256 cplus;
        // cminus ≥ 0 coefficent of decrease of the slope k
        int256 cminus;
        // c0 ≥ 0 minimal rate of decrease of the slope k
        int256 c0;
        // state of the slope after latest interest rate accrual
        int256 k;
    }

    struct Setup {
        // state of the slope after latest interest rate accrual
        int256 k;
        Config config;
    }
    /* solhint-enable */

    error AddressZero();
    error DeployConfigFirst();
    error AlreadyConnected();

    error InvalidUlow();
    error InvalidUopt();
    error InvalidUcrit();
    error InvalidRmin();
    error InvalidKmin();
    error InvalidKmax();
    error InvalidAlpha();
    error InvalidCplus();
    error InvalidCminus();
    error InvalidC0();
    error InvalidK();

    /// @dev Get config for given asset in a Silo. If dedicated config is not set, default one will be returned.
    /// @param _silo Silo address for which config should be set
    /// @return Config struct for asset in Silo
    function getConfig(address _silo) external view returns (ConfigWithState memory);

    /// @notice get the flag to detect rcomp restriction (zero current interest) due to overflow
    /// overflow boolean flag to detect rcomp restriction
    function overflowDetected(address _silo, uint256 _blockTimestamp)
        external
        view
        returns (bool overflow);

    /// @dev pure function that calculates current annual interest rate
    /// @param _c configuration object, IInterestRateModel.ConfigWithState
    /// @param _totalBorrowAmount current total borrows for asset
    /// @param _totalDeposits current total deposits for asset
    /// @param _interestRateTimestamp timestamp of last interest rate update
    /// @param _blockTimestamp current block timestamp
    /// @return rcur current annual interest rate (1e18 == 100%)
    function calculateCurrentInterestRate(
        ConfigWithState calldata _c,
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        uint256 _interestRateTimestamp,
        uint256 _blockTimestamp
    ) external pure returns (uint256 rcur);

    /// @dev pure function that calculates interest rate based on raw input data
    /// @param _c configuration object, IInterestRateModel.ConfigWithState
    /// @param _totalBorrowAmount current total borrows for asset
    /// @param _totalDeposits current total deposits for asset
    /// @param _interestRateTimestamp timestamp of last interest rate update
    /// @param _blockTimestamp current block timestamp
    /// @return rcomp compounded interest rate from last update until now (1e18 == 100%)
    /// @return ri current integral part of the rate
    /// @return Tcrit time during which the utilization exceeds the critical value
    /// @return overflow boolean flag to detect rcomp restriction
    function calculateCompoundInterestRateWithOverflowDetection(
        ConfigWithState memory _c,
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        uint256 _interestRateTimestamp,
        uint256 _blockTimestamp
    )
        external
        pure
        returns (
            uint256 rcomp,
            int256 k
        );

    /// @dev pure function that calculates interest rate based on raw input data
    /// @param _c configuration object, IInterestRateModel.ConfigWithState
    /// @param _totalBorrowAmount current total borrows for asset
    /// @param _totalDeposits current total deposits for asset
    /// @param _interestRateTimestamp timestamp of last interest rate update
    /// @param _blockTimestamp current block timestamp
    /// @return rcomp compounded interest rate from last update until now (1e18 == 100%)
    /// @return ri current integral part of the rate
    /// @return Tcrit time during which the utilization exceeds the critical value
    function calculateCompoundInterestRate(
        ConfigWithState memory _c,
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        uint256 _interestRateTimestamp,
        uint256 _blockTimestamp
    ) external pure returns (uint256 rcomp, int256 k);
}
