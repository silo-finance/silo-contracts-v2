// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";
import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {ErrorsLib} from "./ErrorsLib.sol";
import {EventsLib} from "./EventsLib.sol";
import {PendingUint192, MarketConfig} from "./PendingLib.sol";
import {ConstantsLib} from "./ConstantsLib.sol";

library SiloVaultActionsLib {
    using SafeERC20 for IERC20;

    function setIsAllocator(
        address _newAllocator,
        bool _newIsAllocator,
        mapping(address => bool) storage _isAllocator
    ) external {
        if (_isAllocator[_newAllocator] == _newIsAllocator) revert ErrorsLib.AlreadySet();

        _isAllocator[_newAllocator] = _newIsAllocator;

        emit EventsLib.SetIsAllocator(_newAllocator, _newIsAllocator);
    }

    /// @dev Sets the cap of the market.
    function setCap(
        IERC4626 _market,
        uint184 _supplyCap,
        address _asset,
        mapping(IERC4626 => MarketConfig) storage _config,
        mapping(IERC4626 => PendingUint192) storage _pendingCap,
        IERC4626[] storage _withdrawQueue,
        mapping(address => uint256) storage _withdrawRank
    ) external returns (bool updateTotalAssets) {
        MarketConfig storage marketConfig = _config[_market];
        uint256 approveValue;

        if (_supplyCap > 0) {
            if (!marketConfig.enabled) {
                _withdrawQueue.push(_market);

                // HARNESS
                _withdrawRank[address(_market)] = _withdrawQueue.length + 1;

                if (_withdrawQueue.length > ConstantsLib.MAX_QUEUE_LENGTH) revert ErrorsLib.MaxQueueLengthExceeded();

                marketConfig.enabled = true;

                // Take into account assets of the new market without applying a fee.
                updateTotalAssets = true;

                emit EventsLib.SetWithdrawQueue(msg.sender, _withdrawQueue);
            }

            marketConfig.removableAt = 0;
            // one time approval, so market can pull any amount of tokens from SiloVault in a future
            approveValue = type(uint256).max;
        }

        marketConfig.cap = _supplyCap;
        IERC20(_asset).forceApprove(address(_market), approveValue);

        emit EventsLib.SetCap(msg.sender, _market, _supplyCap);

        delete _pendingCap[_market];
    }

    /// @dev Simulates a withdraw of `assets` from ERC4626 vault.
    /// @return The remaining assets to be withdrawn.
    function simulateWithdrawERC4626(
        uint256 _assets,
        IERC4626[] storage _withdrawQueue
    ) external view returns (uint256) {
        for (uint256 i; i < _withdrawQueue.length; ++i) {
            IERC4626 market = _withdrawQueue[i];

            _assets = UtilsLib.zeroFloorSub(_assets, market.maxWithdraw(address(this)));

            if (_assets == 0) break;
        }

        return _assets;
    }
}
