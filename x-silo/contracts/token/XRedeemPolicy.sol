// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ERC20, IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {Address} from "openzeppelin5/utils/Address.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {TransientReentrancy} from "silo-core/contracts/hooks/_common/TransientReentrancy.sol";
/*
 * xGRAIL is Camelot's escrowed governance token obtainable by converting Silo to it
 * It's non-transferable, except from/to whitelisted addresses
 * It can be converted back to Silo through a vesting process
 * This contract is made to receive xGRAIL deposits from users in order to allocate them to Usages (plugins) contracts
 */
abstract contract XRedeemPolicy is Ownable2Step, TransientReentrancy {
    using Address for address;
    using SafeERC20 for IERC20;

    struct RedeemInfo {
        uint256 siloAmount;
        uint256 xSiloAmount;
        uint256 xSiloAfterVestingRatio;
        uint256 endTime;
    }

    IERC20 public immutable siloToken; // Silo token to convert to/from

    /// @dev constant used to require redeem ratio to not be more than 100%, 100 == 100%
    uint256 public constant MAX_FIXED_RATIO = 100; // 100%

    // Redeeming min/max settings are updatable at any time by owner

    uint256 public minRedeemRatio = 50; // 1:0.5
    uint256 public maxRedeemRatio = 100; // 1:1
    uint256 public minRedeemDuration = 15 days; // 1296000s
    uint256 public maxRedeemDuration = 90 days; // 7776000s

    mapping(address => RedeemInfo[]) public userRedeems;

    event UpdateRedeemSettings(uint256 minRedeemRatio, uint256 maxRedeemRatio, uint256 minRedeemDuration, uint256 maxRedeemDuration);
    event StartRedeem(address indexed userAddress, uint256 siloAmount, uint256 xSiloAmount, uint256 xSiloAfterVestingRatio, uint256 duration);
    event FinalizeRedeem(address indexed userAddress, uint256 xSiloToRedeem, uint256 xSiloToBurn);
    event CancelRedeem(address indexed userAddress, uint256 xSiloToReturn, uint256 xSiloToBurn);

    modifier validateRedeem(address userAddress, uint256 redeemIndex) {
        require(redeemIndex < userRedeems[userAddress].length, "validateRedeem: redeem entry does not exist");
        _;
    }

    function getAmountByVestingDuration(uint256 amount, uint256 duration) public view returns (uint256 underlyingAmount) {
        if (duration < minRedeemDuration) {
            return 0;
        }

        // capped to maxRedeemDuration
        if (duration > maxRedeemDuration) {
            return amount * maxRedeemRatio / 100;
        }

        uint256 ratio = minRedeemRatio + ((duration - minRedeemDuration) * (maxRedeemRatio - minRedeemRatio) / (maxRedeemDuration - minRedeemDuration));

        return amount * ratio / 100;
    }

    function getUserRedeemsBalance(address userAddress) external view returns (uint256 redeemingAmount) {
        uint256 len = userRedeems[userAddress].length;

        if (len == 0) return 0;

        for (uint256 i = 0; i < len; i++) {
            RedeemInfo storage redeemCache = userRedeems[userAddress][i];
            redeemingAmount += redeemCache.siloAmount;
        }
    }

    function getUserRedeemsLength(address userAddress) external view returns (uint256) {
        return userRedeems[userAddress].length;
    }

    function getUserRedeem(address userAddress, uint256 redeemIndex)
        external
        view
        validateRedeem(userAddress, redeemIndex)
        returns (uint256 siloAmount, uint256 xSiloAmount, uint256 xSiloAfterVestingRatio, uint256 endTime)
    {
        RedeemInfo storage redeemCache = userRedeems[userAddress][redeemIndex];
        return (redeemCache.siloAmount, redeemCache.xSiloAmount, redeemCache.xSiloAfterVestingRatio, redeemCache.endTime);
    }

    function updateRedeemSettings(uint256 _minRedeemRatio, uint256 _maxRedeemRatio, uint256 _minRedeemDuration, uint256 _maxRedeemDuration) external onlyOwner {
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

    /* TODO we need public method for that
    all custom methods related to queue management should be implemented in this contract
    */
    function _redeemXSilo(uint256 xSiloAmount, uint256 duration) internal {
        require(xSiloAmount > 0, "redeem: xSiloAmount cannot be null");
        require(duration >= minRedeemDuration, "redeem: duration too low");

        _transferShares(msg.sender, address(this), xSiloAmount);

        // get corresponding SILO amount based on duration
        uint256 xSiloAfterVestingRatio = getAmountByVestingDuration(xSiloAmount, duration);
        uint256 siloAmount = convertToAssets(xSiloAmount);

        emit StartRedeem(msg.sender, siloAmount, xSiloAmount, xSiloAfterVestingRatio, duration);

        // if redeeming is not immediate, go through vesting process
        if (duration > 0) {
            // add redeeming entry
            userRedeems[msg.sender].push(
                RedeemInfo({
                    siloAmount: siloAmount,
                    xSiloAmount: xSiloAmount,
                    xSiloAfterVestingRatio: xSiloAfterVestingRatio,
                    endTime: block.timestamp + duration
                })
            );
        } else {
            // immediately redeem for SILO
            _redeemAndBurn(msg.sender, xSiloAfterVestingRatio, xSiloAmount - xSiloAfterVestingRatio);
        }
    }

    function _finalizeRedeem(uint256 redeemIndex) internal validateRedeem(msg.sender, redeemIndex) {
        RedeemInfo storage redeemCache = userRedeems[msg.sender][redeemIndex];
        require(block.timestamp >= redeemCache.endTime, "finalizeRedeem: vesting duration has not ended yet");

        _redeemAndBurn(msg.sender, redeemCache.xSiloAfterVestingRatio, redeemCache.xSiloAmount - redeemCache.xSiloAfterVestingRatio);

        // remove redeem entry
        _deleteRedeemEntry(redeemIndex);
    }

    function _redeemAndBurn(address userAddress, uint256 xSiloToRedeem, uint256 xSiloToBurn) internal {
        redeem(xSiloToRedeem, userAddress, address(this));
        _burnShares(userAddress, xSiloToBurn);

        emit FinalizeRedeem(userAddress, xSiloToRedeem, xSiloToBurn);
    }

    function cancelRedeem(uint256 redeemIndex) external nonReentrant validateRedeem(msg.sender, redeemIndex) {
        RedeemInfo storage redeemCache = userRedeems[msg.sender][redeemIndex];

        uint256 xSiloToReturn = convertToShares(redeemCache.siloAmount);
        uint256 xSiloToBurn = redeemCache.xSiloAmount - xSiloToReturn;

        _burnShares(msg.sender, xSiloToBurn);
        _transferShares(address(this), msg.sender, xSiloToReturn);

        emit CancelRedeem(msg.sender, xSiloToReturn, xSiloToBurn);

        // remove redeem entry
        _deleteRedeemEntry(redeemIndex);
    }

    function _deleteRedeemEntry(uint256 index) internal {
        userRedeems[msg.sender][index] = userRedeems[msg.sender][userRedeems[msg.sender].length - 1];
        userRedeems[msg.sender].pop();
    }

    function redeem(uint256 _shares, address _receiver, address _owner) public virtual returns (uint256);

    function convertToShares(uint256 _value) public virtual returns (uint256);

    function convertToAssets(uint256 _value) public virtual returns (uint256);

    function _transferShares(address _from, address _to, uint256 _value) internal virtual;

    function _burnShares(address _owner, uint256 _shares) internal virtual;
}