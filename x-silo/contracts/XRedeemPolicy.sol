// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ERC20, IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {TransientReentrancy} from "silo-core/contracts/hooks/_common/TransientReentrancy.sol";

/// @dev based on Camelot's xGRAIL
/// @notice Policy for redeem xSilo back to Silo
abstract contract XRedeemPolicy is Ownable2Step, TransientReentrancy {
    struct RedeemInfo {
        uint256 currentSiloAmount;
        uint256 xSiloAmountToBurn;
        uint256 siloAmountAfterVesting;
        uint256 endTime;
    }

    uint256 constant _PRECISION = 100;

    /// @dev Silo token to convert to/from
    IERC20 public immutable siloToken;

    /// @dev constant used to require redeem ratio to not be more than 100%, 100 == 100%
    uint256 public constant MAX_FIXED_RATIO = _PRECISION; // 100%

    // Redeeming min/max settings are updatable at any time by owner

    /// @dev `minRedeemRatio` together with `maxRedeemRatio` is used to create range of ratios
    /// based on which redeem amount is calculated, value is in 2 decimals, 100 == 1.0, eg 50 means ratio of 1:0.5
    uint256 public minRedeemRatio = 0.5e2; // 1:0.5

    /// @dev `minRedeemRatio` together with `maxRedeemRatio` is used to create range of ratios
    /// based on which redeem amount is calculated, value is in 2 decimals, 100 == 1.0, eg 100 means ratio of 1:1
    uint256 public maxRedeemRatio = 1e2; // 1:1

    /// @dev `minRedeemDuration` together with `maxRedeemDuration` is used to create range of durations
    /// based on which redeem amount is calculated, value is in seconds.
    /// Eg if set to 2 days, redeem attempt for less duration will be reverted and preview method for lower duration
    /// will return 0. `minRedeemDuration` can be set to 0, in that case immediate redeem will be possible but it will
    /// generate loss.
    uint256 public minRedeemDuration = 0 days;

    /// @dev `minRedeemDuration` together with `maxRedeemDuration` is used to create range of durations
    /// based on which redeem amount is calculated, value is in seconds.
    /// Eg if set to 10 days, redeem attempt for less duration will calculate amount based on range, and enything above
    /// will result in 100% of tokens.
    uint256 public maxRedeemDuration = 6 * 30 days; // 6 months

    mapping(address => RedeemInfo[]) public userRedeems;

    event UpdateRedeemSettings(uint256 minRedeemRatio, uint256 maxRedeemRatio, uint256 minRedeemDuration, uint256 maxRedeemDuration);
    event StartRedeem(address indexed _userAddress, uint256 currentSiloAmount, uint256 xSiloToBurn, uint256 siloAmountAfterVesting, uint256 duration);
    event FinalizeRedeem(address indexed _userAddress, uint256 siloToRedeem, uint256 xSiloToBurn);
    event CancelRedeem(address indexed _userAddress, uint256 xSiloToMint);

    modifier validateRedeem(address _userAddress, uint256 _redeemIndex) {
        require(_redeemIndex < userRedeems[_userAddress].length, "validateRedeem: redeem entry does not exist");
        _;
    }

    function getXAmountByVestingDuration(uint256 _xSiloAmount, uint256 _duration)
        public
        view
        virtual
        returns (uint256 xSiloAfterVesting)
    {
        if (_xSiloAmount == 0) {
            return 0;
        }

        uint256 ratio = _calculateRatio(_duration);
        if (ratio == 0) return 0;

        xSiloAfterVesting = _xSiloAmount * ratio / _PRECISION;
    }

    function getAmountInByVestingDuration(uint256 _xSiloAfterVesting, uint256 _duration)
        public
        view
        virtual
        returns (uint256 xSiloAmountIn)
    {
        if (_xSiloAfterVesting == 0) {
            return 0;
        }

        uint256 ratio = _calculateRatio(_duration);
        if (ratio == 0) return type(uint256).max;

        xSiloAmountIn = _xSiloAfterVesting * _PRECISION / ratio;
    }

    function getUserRedeemsBalance(address _userAddress)
        external
        view
        virtual
        returns (uint256 redeemingSiloAmount)
    {
        uint256 len = userRedeems[_userAddress].length;

        if (len == 0) return 0;

        for (uint256 i = 0; i < len; i++) {
            RedeemInfo storage redeemCache = userRedeems[_userAddress][i];
            redeemingSiloAmount += redeemCache.siloAmountAfterVesting;
        }
    }

    function getUserRedeemsLength(address _userAddress) external view returns (uint256) {
        return userRedeems[_userAddress].length;
    }

    function getUserRedeem(address _userAddress, uint256 _redeemIndex)
        external
        view
        validateRedeem(_userAddress, _redeemIndex)
        returns (uint256 currentSiloAmount, uint256 xSiloAmount, uint256 siloAmountAfterVesting, uint256 endTime)
    {
        RedeemInfo storage redeemCache = userRedeems[_userAddress][_redeemIndex];

        return (
            redeemCache.currentSiloAmount,
            redeemCache.xSiloAmountToBurn,
            redeemCache.siloAmountAfterVesting,
            redeemCache.endTime
        );
    }

    function updateRedeemSettings(
        uint256 _minRedeemRatio,
        uint256 _maxRedeemRatio,
        uint256 _minRedeemDuration,
        uint256 _maxRedeemDuration
    ) external onlyOwner {
        require(_minRedeemRatio <= _maxRedeemRatio, "updateRedeemSettings: wrong ratio values");
        require(_minRedeemDuration < _maxRedeemDuration, "updateRedeemSettings: wrong duration values");
        // should never exceed 100%
        require(_maxRedeemRatio <= MAX_FIXED_RATIO, "updateRedeemSettings: wrong ratio values");

        minRedeemRatio = _minRedeemRatio;
        maxRedeemRatio = _maxRedeemRatio;
        minRedeemDuration = _minRedeemDuration;
        maxRedeemDuration = _maxRedeemDuration;

        emit UpdateRedeemSettings(_minRedeemRatio, _maxRedeemRatio, _minRedeemDuration, _maxRedeemDuration);
    }

    /// @notice on redeem, `_xSiloAmount` of shares are burned, so it is no longer available
    /// when cancel, `_xSiloAmount` of shares will be minted back
    function redeemSilo(uint256 _xSiloAmountToBurn, uint256 _duration)
        external
        virtual
        nonReentrant
        returns (uint256 siloAmountAfterVesting)
    {
        require(_xSiloAmountToBurn > 0, "redeem: xSiloAmount cannot be null");
        require(_duration >= minRedeemDuration, "redeem: duration too low");

        // get corresponding SILO amount based on duration
        uint256 xSiloAfterVesting = getXAmountByVestingDuration(_xSiloAmountToBurn, _duration);
        // TODO question: convertToAssets will give us current value,
        // should user got future value? if so, we need to convert on finalizing
        siloAmountAfterVesting = convertToAssets(xSiloAfterVesting);
        uint256 currentSiloAmount = convertToAssets(_xSiloAmountToBurn);

        emit StartRedeem(msg.sender, currentSiloAmount,_xSiloAmountToBurn, siloAmountAfterVesting, _duration);

        // if redeeming is not immediate, go through vesting process
        if (_duration > 0) {
            // add redeeming entry
            userRedeems[msg.sender].push(
                RedeemInfo({
                    currentSiloAmount: currentSiloAmount,
                    xSiloAmountToBurn: _xSiloAmountToBurn,
                    siloAmountAfterVesting: siloAmountAfterVesting,
                    endTime: block.timestamp + _duration
                })
            );

            _transferShares(msg.sender, address(this), _xSiloAmountToBurn);
        } else {
            // immediately redeem for SILO
            _withdraw({
                _caller: msg.sender,
                _receiver: msg.sender,
                _owner: msg.sender,
                _assetsToTransfer: siloAmountAfterVesting,
                _sharesToBurn: _xSiloAmountToBurn
            });
        }
    }

    function finalizeRedeem(uint256 redeemIndex) external nonReentrant validateRedeem(msg.sender, redeemIndex) {
        RedeemInfo storage redeemCache = userRedeems[msg.sender][redeemIndex];
        require(block.timestamp >= redeemCache.endTime, "finalizeRedeem: vesting duration has not ended yet");

        _withdraw({
            _caller: msg.sender,
            _receiver: msg.sender,
            _owner: msg.sender,
            _assetsToTransfer: redeemCache.siloAmountAfterVesting,
            _sharesToBurn: redeemCache.xSiloAmountToBurn
        });

        // remove redeem entry
        _deleteRedeemEntry(redeemIndex);

        emit FinalizeRedeem(msg.sender, redeemCache.siloAmountAfterVesting, redeemCache.xSiloAmountToBurn);
    }

    function _calculateRatio(uint256 _duration)
        internal
        view
        virtual
        returns (uint256 ratio)
    {
        if (_duration < minRedeemDuration) {
            return 0;
        }

        // capped to maxRedeemDuration
        if (_duration > maxRedeemDuration) {
            return maxRedeemRatio;
        }

        ratio = minRedeemRatio +
            Math.mulDiv(
                _duration - minRedeemDuration,
                maxRedeemRatio - minRedeemRatio,
                maxRedeemDuration - minRedeemDuration
            );
    }

    function cancelRedeem(uint256 _redeemIndex) external nonReentrant validateRedeem(msg.sender, _redeemIndex) {
        RedeemInfo storage redeemCache = userRedeems[msg.sender][_redeemIndex];

        uint256 xSiloBeforeRedeem = convertToShares(redeemCache.currentSiloAmount);
        uint256 toTransfer = redeemCache.xSiloAmountToBurn - xSiloBeforeRedeem;
        uint256 toBurn = redeemCache.xSiloAmountToBurn - toTransfer;

        _transferShares(address(this), msg.sender, toTransfer);
        _burnShares(address(this), toBurn);

        emit CancelRedeem(msg.sender, redeemCache.xSiloAmountToBurn);

        // remove redeem entry
        _deleteRedeemEntry(_redeemIndex);
    }

    function _deleteRedeemEntry(uint256 _index) internal {
        userRedeems[msg.sender][_index] = userRedeems[msg.sender][userRedeems[msg.sender].length - 1];
        userRedeems[msg.sender].pop();
    }

    function convertToAssets(uint256 _shares) public virtual returns (uint256);

    function convertToShares(uint256 _assets) public virtual returns (uint256);

    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assetsToTransfer,
        uint256 _sharesToBurn
    ) internal virtual;


    function _burnShares(address _account, uint256 _shares) internal virtual;

    function _transferShares(address _from, address _to, uint256 _shares) internal virtual;
}