// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;


interface IInterestRateModel {
    /// @dev optional method that can connect silo to it's model state on silo initialization
    /// can be empty by must implement interface.
    function connect(address _configAddress) external;

    /// @dev get compound interest rate and update model storage for current block.timestamp
    /// @param _collateralAssets total silo collateral assets
    /// @param _debtAssets total silo debt assets
    /// @param _interestRateTimestamp last IRM timestamp
    /// @return rcomp compounded interest rate from last update until now (1e18 == 100%)
    function getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    )
        external
        returns (uint256 rcomp);

    /// @dev get compound interest rate
    /// @param _silo address of Silo for which interest rate should be calculated
    /// @param _blockTimestamp current block timestamp
    /// @return rcomp compounded interest rate from last update until now (1e18 == 100%)
    function getCompoundInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        returns (uint256 rcomp);

    /// @dev get current annual interest rate
    /// @param _silo address of Silo for which interest rate should be calculated
    /// @param _blockTimestamp current block timestamp
    /// @return rcur current annual interest rate (1e18 == 100%)
    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        returns (uint256 rcur);

    /// @dev returns decimal points used by model
    // todo from ERC20 Returns the number of decimals the token uses - e.g. 8, means to divide the token amount by 100000000 to get its user representation
    function decimals() external view returns (uint256);
}
