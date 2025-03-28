// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";
import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";

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
        IERC4626[] storage _withdrawQueue
    ) external returns (bool updateTotalAssets) {
        MarketConfig storage marketConfig = _config[_market];
        uint256 approveValue;

        if (_supplyCap > 0) {
            if (!marketConfig.enabled) {
                _withdrawQueue.push(_market);

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

    function maxDeposit(
        IERC4626[] memory _supplyQueue,
        mapping(IERC4626 => MarketConfig) storage _config,
        mapping(IERC4626 => uint256) storage _balanceTracker
    )
        external
        view
        returns (uint256 totalSuppliable)
    {
        uint256 length = _supplyQueue.length;

        for (uint256 i; i < length; ++i) {
            IERC4626 market = _supplyQueue[i];

            uint256 supplyCap = _config[market].cap;
            if (supplyCap == 0) continue;

            (uint256 assets,) = supplyBalance(market);
            uint256 depositMax = market.maxDeposit(address(this));
            uint256 suppliable = Math.min(depositMax, UtilsLib.zeroFloorSub(supplyCap, assets));

            if (suppliable == 0) continue;

            uint256 internalBalance = _balanceTracker[market];

            // We reached a cap of the market by internal balance, so we can't supply more
            if (internalBalance >= supplyCap) continue;

            uint256 internalSuppliable;
            // safe to uncheck because internalBalance < supplyCap
            unchecked { internalSuppliable = supplyCap - internalBalance; }

            totalSuppliable += Math.min(suppliable, internalSuppliable);
        }
    }

    /// @dev Returns the vault's assets & corresponding shares supplied on the
    /// market defined by `market`, as well as the market's state.
    function supplyBalance(IERC4626 _market)
        internal
        view
        returns (uint256 assets, uint256 shares)
    {
        shares = ERC20BalanceOf(address(_market), address(this));
        // we assume here, that in case of any interest on IERC4626, convertToAssets returns assets with interest
        assets = previewRedeem(_market, shares);
    }

    /// @dev to save code size ~500 B
    function ERC20BalanceOf(address _token, address _account) internal view returns (uint256 balance) {
        balance = IERC20(_token).balanceOf(_account);
    }

    function previewRedeem(IERC4626 _market, uint256 _shares) internal view returns (uint256 assets) {
        if (_shares == 0) return 0;

        assets = _market.previewRedeem(_shares);
    }
}
