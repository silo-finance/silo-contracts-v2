// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

// import {IInterestRateModel} from "./IInterestRateModel.sol";
// interface IDynamicKinkModelV1 is IInterestRateModel {
    interface IDynamicKinkModelV1 {
    struct Config {
        // ulow ∈ [0, 1) – threshold of low utilization;
        int256 ulow;
        // u1 ∈ [0, 1) – lower bound of optimal utilization range;
        int256 u1;
        // u2 ∈ [u1, 1] – upper bound of optimal utilization range;
        int256 u2;
        // ucrit ∈ [ulow, 1] – threshold of critical utilization;
        int256 ucrit;
        // rmin ⩾ 0 – minimal per-second interest rate;
        int256 rmin;
        // kmin ⩾ 0 – minimal slope k of central segment of the kink;
        int256 kmin;
        // kmax ⩾ kmin – maximal slope k of central segment of the kink;
        int256 kmax;
        // dmax – maximal growth rate of the slope k;
        int256 dmax;
        // α ⩾ 0 – factor for the slope for the critical segment of the kink;
        int256 alpha;
        // c− ⩾ 0 – coefficient of decrease of the slope k;
        int256 cminus;
        // c+ ⩾ 0 – growth coefficient of the slope k;
        int256 cplus;
        // c1 ⩾ 0 – minimal rate of decrease of the slope k;
        int256 c1;
        // c2 ⩾ 0 – minimal growth rate of the slope k.
        int256 c2;
    }

    struct Setup {
        // constant config
        Config config;
        // state of the slope after latest interest rate accrual
        int256 k;
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

    // @ natspec todo
    /// dev Get config for given asset in a Silo. If dedicated config is not set, default one will be returned.
    /// param _silo Silo address for which config should be set
    /// return Config struct for asset in Silo
    // function getSetup(address _silo) external view returns (Setup memory);

    /// dev pure function that calculates current annual interest rate
    /// param _c configuration object, IInterestRateModel.ConfigWithState
    /// param _totalBorrowAmount current total borrows for asset
    /// param _totalDeposits current total deposits for asset
    /// param _interestRateTimestamp timestamp of last interest rate update
    /// param _blockTimestamp current block timestamp
    /// return rcur current annual interest rate (1e18 == 100%)
    // function calculateCurrentInterestRate(
    //     Setup calldata _setup,
    //     uint256 _totalDeposits,
    //     uint256 _totalBorrowAmount,
    //     uint256 _interestRateTimestamp,
    //     uint256 _blockTimestamp
    // ) external pure returns (uint256 rcur);

    /// dev pure function that calculates interest rate based on raw input data
    /// param _c configuration object, IInterestRateModel.ConfigWithState
    /// param _totalBorrowAmount current total borrows for asset
    /// param _totalDeposits current total deposits for asset
    /// param _interestRateTimestamp timestamp of last interest rate update
    /// param _blockTimestamp current block timestamp
    /// return rcomp compounded interest rate from last update until now (1e18 == 100%)
    /// return ri current integral part of the rate
    /// return Tcrit time during which the utilization exceeds the critical value
    // function calculateCompoundInterestRate(
    //     Setup calldata _setup,
    //     uint256 _totalDeposits,
    //     uint256 _totalBorrowAmount,
    //     uint256 _interestRateTimestamp,
    //     uint256 _blockTimestamp
    // ) external pure returns (uint256 rcomp, int256 k);
}
