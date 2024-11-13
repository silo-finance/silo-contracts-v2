// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Address} from "openzeppelin5/contracts/utils/Address.sol";
import {IERC20} from "openzeppelin5/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC3156FlashBorrower} from "../../interfaces/IERC3156FlashBorrower.sol";
import {IPartialLiquidation} from "../../interfaces/IPartialLiquidation.sol";
import {ILiquidationHelper} from "../../interfaces/ILiquidationHelper.sol";

import "../interfaces/IWrappedNativeToken.sol";

import "../../lib/RevertLib.sol";

import "./DexSwap.sol";

/// @notice LiquidationHelper IS NOT PART OF THE PROTOCOL. SILO CREATED THIS TOOL, MOSTLY AS AN EXAMPLE.
/// see https://github.com/silo-finance/liquidation#readme for details how liquidation process should look like
contract LiquidationHelper is ILiquidationHelper, IERC3156FlashBorrower, DexSwap {
    using RevertLib for bytes;
    using SafeERC20 for IERC20;
    using Address for address payable;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    /// @dev token receiver will get all rewards from liquidation, does not matter who will execute tx
    address payable public immutable TOKENS_RECEIVER;
    
    constructor (
        address _exchangeProxy,
        address payable _tokensReceiver,
        bool _checkProfitability
    ) DexSwap(_exchangeProxy) {
        EXCHANGE_PROXY = _exchangeProxy;
        TOKENS_RECEIVER = _tokensReceiver;
    }

    receive() external payable {}

    /// @param _collateralSilo silo address where `_user` has collateral
    function executeLiquidation(
        ISilo _collateralSilo,
        address _user,
        IPartialLiquidation _liquidationHook,
        address _debtAsset,
        address _collateralAsset,
        uint256 _maxDebtToCover,
        bool sTokenRequired,
        ISilo _flashLoanFrom,
        SwapInput0x[] calldata _swapsInputs0x
    ) external {
        require(_maxDebtToCover != 0, NoDebtToCover());

        _flashLoanFrom.flashLoan(
            address(this),
            _debtAsset,
            _maxDebtToCover,
            abi.encode(_collateralSilo, _user, _collateralAsset, _liquidationHook, sTokenRequired, _swapsInputs0x)
        );
    }

    function onFlashLoan(
        address _initiator,
        address _debtAsset,
        uint256 _debtToRepay,
        uint256 _fee,
        bytes calldata _data
    )
        external
        returns (bytes32)
    {
        (
            ISilo _collateralSilo,
            address user,
            address collateralAsset,
            IPartialLiquidation liquidationHook,
            bool _receiveSToken,
            SwapInput0x[] memory _swapsInputs0x
        ) = abi.encode(_data, (address, address, IPartialLiquidation, bool, SwapInput0x[]));

        unchecked {
            // if we overflow on +fee, we can not transfer it anyway
            IERC20(_debtAsset).approve(address(liquidationHook), _debtToRepay + _fee);
        }

        (
            uint256 withdrawCollateral, uint256 repayDebtAssets
        ) = liquidationHook.liquidationCall(collateralAsset, _debtAsset, user, _debtToRepay, _receiveSToken);

        // we need to swap collateral to repay flashloan fee
        _execute0x(_swapsInputs0x);

        if (repayDebtAssets < _debtToRepay) {
            // revert? transfer change?
        }

        if (withdrawCollateral != 0) {
            if (_receiveSToken) {
                (
                    address protectedShareToken, address collateralShareToken,
                ) = liquidationHook.siloConfig().getShareTokens(_collateralSilo);

                uint256 balance = IERC20(collateralShareToken).balanceOf(address(this));
                if (balance != 0) IERC20(collateralShareToken).transfer(TOKENS_RECEIVER, balance);

                balance = IERC20(protectedShareToken).balanceOf(address(this));
                if (balance != 0) IERC20(protectedShareToken).transfer(TOKENS_RECEIVER, balance);
            } else {
                IERC20(collateralAsset).transfer(TOKENS_RECEIVER, withdrawCollateral);
            }
        }

        return _FLASHLOAN_CALLBACK;
    }

    function _execute0x(SwapInput0x[] memory _swapInputs) internal {
        for (uint256 i; i < _swapInputs.length; i++) {
            fillQuote(_swapInputs[i].sellToken, _swapInputs[i].allowanceTarget, _swapInputs[i].swapCallData);
        }
    }

    /// @notice We assume that quoteToken is wrapped native token
    function _transferNative(address payable _to, uint256 _amount) internal {
        IWrappedNativeToken(address(QUOTE_TOKEN)).withdraw(_amount);
        _to.sendValue(_amount);
    }
}
