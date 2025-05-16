// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dev based on Camelot's xGRAIL
/// @notice Policy for redeem xSilo back to Silo
interface IXRedeemPolicy {
    struct RedeemInfo {
        uint256 currentSiloAmount;
        uint256 xSiloAmountToBurn;
        uint256 siloAmountAfterVesting;
        uint256 endTime;
    }
    
    event UpdateRedeemSettings(
        uint256 minRedeemRatio,
        uint256 maxRedeemRatio,
        uint256 minRedeemDuration,
        uint256 maxRedeemDuration
    );

    event StartRedeem(
        address indexed _userAddress,
        uint256 currentSiloAmount,
        uint256 xSiloToBurn,
        uint256 siloAmountAfterVesting,
        uint256 duration
    );

    event FinalizeRedeem(address indexed _userAddress, uint256 siloToRedeem, uint256 xSiloToBurn);
    event CancelRedeem(address indexed _userAddress, uint256 xSiloToTransfer, uint256 xSiloToBurn);

    error ZeroAmount();
    error NoSiloToRedeem();
    error RedeemIndexDoesNotExist();
    error InvalidRatioOrder();
    error InvalidDurationOrder();
    error MaxRatioOverflow();
    error DurationTooLow();
    error VestingNotOver();


    /// @dev constant used to require redeem ratio to not be more than 100%, 100 == 100%
    function MAX_FIXED_RATIO() external view returns (uint256);

    // Redeeming min/max settings are updatable at any time by owner

    /// @dev `minRedeemRatio` together with `maxRedeemRatio` is used to create range of ratios
    /// based on which redeem amount is calculated, value is in 2 decimals, 100 == 1.0, eg 50 means ratio of 1:0.5
    function minRedeemRatio() external view returns (uint256);

    /// @dev `minRedeemRatio` together with `maxRedeemRatio` is used to create range of ratios
    /// based on which redeem amount is calculated, value is in 2 decimals, 100 == 1.0, eg 100 means ratio of 1:1
    function maxRedeemRatio() external view returns (uint256);

    /// @dev `minRedeemDuration` together with `maxRedeemDuration` is used to create range of durations
    /// based on which redeem amount is calculated, value is in seconds.
    /// Eg if set to 2 days, redeem attempt for less duration will be reverted and preview method for lower duration
    /// will return 0. `minRedeemDuration` can be set to 0, in that case immediate redeem will be possible but it will
    /// generate loss.
    function minRedeemDuration() external view returns (uint256);

    /// @dev `minRedeemDuration` together with `maxRedeemDuration` is used to create range of durations
    /// based on which redeem amount is calculated, value is in seconds.
    /// Eg if set to 10 days, redeem attempt for less duration will calculate amount based on range, and anything above
    /// will result in 100% of tokens.
    function maxRedeemDuration() external view returns (uint256);

    function userRedeems(address) external view returns (RedeemInfo[] memory);

    function updateRedeemSettings(
        uint256 _minRedeemRatio,
        uint256 _maxRedeemRatio,
        uint256 _minRedeemDuration,
        uint256 _maxRedeemDuration
    ) external;

    /// @notice on redeem, `_xSiloAmount` of shares are burned, so it is no longer available
    /// when cancel, `_xSiloAmount` of shares will be minted back
    function redeemSilo(uint256 _xSiloAmountToBurn, uint256 _duration)
        external
        returns (uint256 siloAmountAfterVesting);

    function finalizeRedeem(uint256 redeemIndex) external;

    function cancelRedeem(uint256 _redeemIndex) external;

    function getUserRedeemsBalance(address _userAddress)
        external
        view
        returns (uint256 redeemingSiloAmount);

    function getUserRedeemsLength(address _userAddress) external view returns (uint256);

    function getUserRedeem(address _userAddress, uint256 _redeemIndex)
        external
        view
        returns (uint256 currentSiloAmount, uint256 xSiloAmount, uint256 siloAmountAfterVesting, uint256 endTime);

    /// @param _xSiloAmount xSilo amount to redeem for Silo
    /// @param _duration duration in seconds after which redeem happen
    /// @return siloAmountAfterVesting Silo amount user will get after duration
    function getAmountByVestingDuration(uint256 _xSiloAmount, uint256 _duration)
        external
        view
        
        returns (uint256 siloAmountAfterVesting);

    /// @param _xSiloAmount xSilo amount to use for vesting
    /// @param _duration duration in seconds
    /// @return xSiloAfterVesting xSilo amount will be used for redeem after vesting
    function getXAmountByVestingDuration(uint256 _xSiloAmount, uint256 _duration)
        external
        view
        returns (uint256 xSiloAfterVesting);

    /// @dev reversed method for getXAmountByVestingDuration
    /// @param _xSiloAfterVesting amount after vesting
    /// @param _duration duration in seconds
    /// @return xSiloAmountIn xSilo amount user will spend to get `_xSiloAfterVesting`
    function getAmountInByVestingDuration(uint256 _xSiloAfterVesting, uint256 _duration)
        external
        view
        returns (uint256 xSiloAmountIn);

    function convertToAssets(uint256 _shares) external view returns (uint256);

    function convertToShares(uint256 _assets) external view returns (uint256);
}
