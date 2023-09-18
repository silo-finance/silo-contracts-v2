// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;


interface IInterestRateModel {
    /// @dev optional method that can connect silo to it's model state on silo initialization
    /// can be empty by must implement interface.
    function connect(address _configAddress) external;

    /// @dev get compound interest rate and update model storage
    /// @param _blockTimestamp current block timestamp
    /// @return rcomp compounded interest rate from last update until now (1e18 == 100%)
    function getCompoundInterestRateAndUpdate(uint256 _blockTimestamp)
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
    function decimals() external view returns (uint256);
}
