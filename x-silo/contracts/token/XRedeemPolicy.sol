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
        uint256 siloAmountAfterVesting;
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
    event StartRedeem(address indexed _userAddress, uint256 siloAmount, uint256 xSiloAmount, uint256 siloAmountAfterVesting, uint256 duration);
    event FinalizeRedeem(address indexed _userAddress, uint256 xSiloToRedeem, uint256 xSiloToBurn);
    event CancelRedeem(address indexed _userAddress, uint256 xSiloToReturn, uint256 xSiloToBurn);

    modifier validateRedeem(address _userAddress, uint256 redeemIndex) {
        require(redeemIndex < userRedeems[_userAddress].length, "validateRedeem: redeem entry does not exist");
        _;
    }

    function getAmountByVestingDuration(uint256 _xSiloAmount, uint256 _duration)
        public
        view
        virtual
        returns (uint256 siloAmount)
    {
        if (_xSiloAmount == 0 || _duration < minRedeemDuration) {
            return 0;
        }

        // capped to maxRedeemDuration
        if (_duration > maxRedeemDuration) {
            return _xSiloAmount * maxRedeemRatio / 100;
        }

        uint256 ratio = minRedeemRatio +
            Math.mulDiv(
                _duration - minRedeemDuration,
                maxRedeemRatio - minRedeemRatio,
                maxRedeemDuration - minRedeemDuration
            );

        siloAmount = _xSiloAmount * ratio / 100;
    }

    function getSharesByVestingDuration(uint256 _siloAmount, uint256 _duration)
        public
        view
        virtual
        returns (uint256 xSiloAmount)
    {
        if (_siloAmount == 0 || _duration < minRedeemDuration) {
            return 0;
        }

        // capped to maxRedeemDuration
        if (_duration > maxRedeemDuration) {
            return _siloAmount * 100 / maxRedeemRatio;
        }

        uint256 ratio = minRedeemRatio +
            Math.mulDiv(
                _duration - minRedeemDuration,
                maxRedeemRatio - minRedeemRatio,
                maxRedeemDuration - minRedeemDuration
            );

        xSiloAmount = _siloAmount * 100 / ratio;
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
            redeemingSiloAmount += redeemCache.siloAmount;
        }
    }

    function getUserRedeemsLength(address _userAddress) external view returns (uint256) {
        return userRedeems[_userAddress].length;
    }

    function getUserRedeem(address _userAddress, uint256 _redeemIndex)
        external
        view
        validateRedeem(_userAddress, _redeemIndex)
        returns (uint256 siloAmount, uint256 xSiloAmount, uint256 siloAmountAfterVesting, uint256 endTime)
    {
        RedeemInfo storage redeemCache = userRedeems[_userAddress][_redeemIndex];

        return (
            redeemCache.siloAmount,
            redeemCache.xSiloAmount,
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

    function redeemXSilo(uint256 _xSiloAmount, uint256 _duration) external virtual {
        require(_xSiloAmount > 0, "redeem: xSiloAmount cannot be null");
        require(_duration >= minRedeemDuration, "redeem: duration too low");

        // TODO
//        _transferShares(msg.sender, address(this), _xSiloAmount);

        // get corresponding SILO amount based on duration
        uint256 siloAmountAfterVesting = getAmountByVestingDuration(_xSiloAmount, _duration);
        uint256 siloAmount = convertToAssets(_xSiloAmount);

        emit StartRedeem(msg.sender, siloAmount, _xSiloAmount, siloAmountAfterVesting, _duration);

        // if redeeming is not immediate, go through vesting process
        if (_duration > 0) {
            // add redeeming entry
            userRedeems[msg.sender].push(
                RedeemInfo({
                    siloAmount: siloAmount,
                    xSiloAmount: _xSiloAmount,
                    siloAmountAfterVesting: siloAmountAfterVesting,
                    endTime: block.timestamp + _duration
                })
            );
        } else {
            // immediately redeem for SILO
            // TODO I think there is a bug here, we need to know shares to redeem, not  siloAmountAfterVesting
            _redeemAndBurn(msg.sender, siloAmountAfterVesting, _xSiloAmount - siloAmountAfterVesting);
        }
    }

    function _finalizeRedeem(uint256 redeemIndex) internal validateRedeem(msg.sender, redeemIndex) {
        RedeemInfo storage redeemCache = userRedeems[msg.sender][redeemIndex];
        require(block.timestamp >= redeemCache.endTime, "finalizeRedeem: vesting duration has not ended yet");

        _redeemAndBurn(msg.sender, redeemCache.siloAmountAfterVesting, redeemCache.xSiloAmount - redeemCache.siloAmountAfterVesting);

        // remove redeem entry
        _deleteRedeemEntry(redeemIndex);
    }

    function _redeemAndBurn(address _userAddress, uint256 _xSiloToRedeem, uint256 _xSiloToBurn) internal {
        // TODO something here is not right, we need separated method to transfer underlying
        // and burn shares
//        _withdraw(msg.sender);
//        _transferShares(_xSiloToRedeem, _userAddress, address(this));
//        _burnShares(_userAddress, _xSiloToBurn);

        emit FinalizeRedeem(_userAddress, _xSiloToRedeem, _xSiloToBurn);
    }

    function cancelRedeem(uint256 _redeemIndex) external nonReentrant validateRedeem(msg.sender, _redeemIndex) {
        RedeemInfo storage redeemCache = userRedeems[msg.sender][_redeemIndex];

        uint256 xSiloToReturn = convertToShares(redeemCache.siloAmount);
        uint256 xSiloToBurn = redeemCache.xSiloAmount - xSiloToReturn;

        // TODO fix this
//        _withdraw(msg.sender, );
//        _burnShares(msg.sender, xSiloToBurn);
//        _transferShares(address(this), msg.sender, xSiloToReturn);

        emit CancelRedeem(msg.sender, xSiloToReturn, xSiloToBurn);

        // remove redeem entry
        _deleteRedeemEntry(_redeemIndex);
    }

    function _deleteRedeemEntry(uint256 _index) internal {
        userRedeems[msg.sender][_index] = userRedeems[msg.sender][userRedeems[msg.sender].length - 1];
        userRedeems[msg.sender].pop();
    }

    function convertToShares(uint256 _value) public virtual returns (uint256);

    function convertToAssets(uint256 _value) public virtual returns (uint256);

//    function _withdraw(
//        address _caller,
//        address _receiver,
//        address _owner,
//        uint256 _assetsToTransfer,
//        uint256 _sharesToBurn
//    ) internal virtual;

    function _burnShares(address _owner, uint256 _shares) internal virtual;
}