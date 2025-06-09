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
        uint256 minRedeemDuration,
        uint256 maxRedeemDuration
    );

    event StartRedeem(
        address indexed userAddress,
        uint256 currentSiloAmount,
        uint256 xSiloToBurn,
        uint256 siloAmountAfterVesting,
        uint256 duration
    );

    event FinalizeRedeem(address indexed userAddress, uint256 siloToRedeem);
    event CancelRedeem(address indexed userAddress, uint256 siloAmountRestored, uint256 xSiloMinted);

    error ZeroAmount();
    error CancelGeneratesZeroShares();
    error NoSiloToRedeem();
    error RedeemIndexDoesNotExist();
    error InvalidRatioOrder();
    error InvalidDurationOrder();
    error MaxRatioOverflow();
    error DurationTooLow();
    error VestingNotOver();
    error DurationTooHigh();

    /// @dev Max redeem duration is capped at 365 days.
    function MAX_REDEEM_DURATION_CAP() external view returns (uint256);

    /// @dev `minRedeemRatio` together with `MAX_REDEEM_RATIO` is used to create range of ratios
    /// based on which redeem amount is calculated, value is in 18 decimals, 1e18 == 1.0, eg 1e18 means ratio of 1:1.
    // `MAX_REDEEM_RATIO` is capped at 1:1.
    function MAX_REDEEM_RATIO() external view returns (uint256);

    // Redeeming min/max settings are updatable at any time by owner

    /// @dev `minRedeemRatio` together with `maxRedeemRatio` is used to create range of ratios
    /// based on which redeem amount is calculated, value is in 18 decimals, 1e18 == 1.0, eg 0.5e18 means ratio of 1:0.5
    function minRedeemRatio() external view returns (uint256);

    /// @dev `minRedeemDuration` together with `maxRedeemDuration` is used to create range of durations
    /// based on which redeem amount is calculated, value is in seconds.
    /// Eg if set to 2 days, redeem attempt for less duration will be reverted and preview method for lower duration
    /// will return 0. `minRedeemDuration` can be set to 0, in that case immediate redeem will be possible but it will
    /// generate loss.
    function minRedeemDuration() external view returns (uint256);

    /// @dev `maxRedeemDuration` together with `minRedeemDuration` is used to create range of durations
    /// based on which redeem amount is calculated, value is in seconds.
    /// Eg if set to 10 days, redeem attempt for less duration will calculate amount based on range, and anything above
    /// will result in 100% of tokens.
    function maxRedeemDuration() external view returns (uint256);

    /// @return returns all `_user`s redeem queue
    function userRedeems(address _user) external view returns (RedeemInfo[] memory);

    /// @dev updates main settings for redeem policy
    /// @param _minRedeemRatio together with `maxRedeemRatio` is used to create range of ratios
    /// based on which redeem amount is calculated, value is in 18 decimals, 1e18 == 1.0, eg 0.5e18 means ratio of 1:0.5
    /// @param _minRedeemDuration together with `maxRedeemDuration` is used to create range of durations
    /// based on which redeem amount is calculated, value is in seconds.
    /// Eg if set to 2 days, redeem attempt for less duration will be reverted and preview method for lower duration
    /// will return 0. `minRedeemDuration` can be set to 0, in that case immediate redeem will be possible but it will
    /// generate loss.
    /// @param _maxRedeemDuration together with `minRedeemDuration` is used to create range of durations
    /// based on which redeem amount is calculated, value is in seconds.
    /// Eg if set to 10 days, redeem attempt for less duration will calculate amount based on range, and anything above
    /// will result in 100% of tokens.
    function updateRedeemSettings(
        uint256 _minRedeemRatio,
        uint256 _minRedeemDuration,
        uint256 _maxRedeemDuration
    ) external;

    /// @notice on redeem, `_xSiloAmount` of shares are burned, so it is no longer available
    /// when cancel, `_xSiloAmount` of shares will be minted back
    function redeemSilo(uint256 _xSiloAmountToBurn, uint256 _duration)
        external
        returns (uint256 siloAmountAfterVesting);

    /// @notice it will finalize user redeem selected by `_redeemIndex`, as result user will get Silo back.
    /// It will revert if duration time for position did not pass yet.
    function finalizeRedeem(uint256 _redeemIndex) external;

    /// @notice It will cancel user redeem item selected by `_redeemIndex`, as result position will be deleted,
    /// user will get back xSilo amount that corresponds to the value of Silo at the moment of creating position.
    /// It can be called anytime, even after duration pass.
    function cancelRedeem(uint256 _redeemIndex) external;

    /// @notice returns total silo amount pending in a redeem queue that user will get after vesting
    function getUserRedeemsBalance(address _userAddress)
        external
        view
        returns (uint256 redeemingSiloAmount);

    /// @notice size of user redeem queue
    function getUserRedeemsLength(address _userAddress) external view returns (uint256);

    /// @notice returns single position from redeem queue
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
}
