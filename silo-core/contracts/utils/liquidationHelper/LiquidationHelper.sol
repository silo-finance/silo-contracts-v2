// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Address} from "openzeppelin5/utils/Address.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {IERC3156FlashBorrower} from "../../interfaces/IERC3156FlashBorrower.sol";
import {IPartialLiquidation} from "../../interfaces/IPartialLiquidation.sol";
import {ILiquidationHelper} from "../../interfaces/ILiquidationHelper.sol";

import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";
import {IWrappedNativeToken} from "../../interfaces/IWrappedNativeToken.sol";

import "./DexSwap.sol";

interface ISiloConfigHelper {
    function siloConfig() external view returns (ISiloConfig);
}

/// @notice LiquidationHelper IS NOT PART OF THE PROTOCOL. SILO CREATED THIS TOOL, MOSTLY AS AN EXAMPLE.
/// see https://github.com/silo-finance/liquidation#readme for details how liquidation process should look like
contract LiquidationHelper is ILiquidationHelper, IERC3156FlashBorrower, DexSwap {
    using Address for address payable;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    /// @dev token receiver will get all rewards from liquidation, does not matter who will execute tx
    address payable public immutable TOKENS_RECEIVER;

    address public immutable NATIVE_TOKEN;

    bool private transient _transferDebt;

    error NoDebtToCover();

    constructor (
        address _nativeToken,
        address _exchangeProxy,
        address payable _tokensReceiver
    ) DexSwap(_exchangeProxy) {
        NATIVE_TOKEN = _nativeToken;
        EXCHANGE_PROXY = _exchangeProxy;
        TOKENS_RECEIVER = _tokensReceiver;
    }

    function executeLiquidation(
        ISilo _flashLoanFrom,
        address _debtAsset,
        uint256 _maxDebtToCover,
        LiquidationData calldata _liquidation,
        SwapInput0x[] calldata _swapsInputs0x
    ) external {
        require(_maxDebtToCover != 0, NoDebtToCover());

        _flashLoanFrom.flashLoan(this, _debtAsset, _maxDebtToCover, abi.encode(_liquidation, _swapsInputs0x));

        if (_transferDebt) _transfer(_debtAsset, IERC20(_debtAsset).balanceOf(address(this)));
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
            LiquidationData memory _liquidation,
            SwapInput0x[] memory _swapsInputs0x
        ) = abi.decode(_data, (LiquidationData, SwapInput0x[]));

        unchecked {
            // if we overflow on +fee, we can not transfer it anyway
            IERC20(_debtAsset).approve(address(_liquidation.hook), _debtToRepay + _fee);
        }

        (
            uint256 withdrawCollateral, uint256 repayDebtAssets
        ) = _liquidation.hook.liquidationCall(
            _liquidation.collateralAsset, _debtAsset, _liquidation.user, _debtToRepay, _liquidation.receiveSToken
        );

        if (repayDebtAssets < _debtToRepay) {
            // if we repay less, then for sure user was insolvent, but maybe price changed?
            _transferDebt = true;
        }

        // swap collateral to repay flashloan fee
        _execute0x(_swapsInputs0x);

        if (withdrawCollateral != 0) {
            if (_liquidation.receiveSToken) {
                uint256 balance = IERC20(_liquidation.collateralShareToken).balanceOf(address(this));
                _transfer(_liquidation.collateralShareToken, balance);

                balance = IERC20(_liquidation.protectedShareToken).balanceOf(address(this));
                _transfer(_liquidation.protectedShareToken, balance);
            } else {
                _transfer(_liquidation.collateralAsset, withdrawCollateral);
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
    function _transfer(address _asset, uint256 _amount) internal {
        if (_amount == 0) return;

        if (_asset == NATIVE_TOKEN) _transferNative(_amount);
        else IERC20(_asset).transfer(TOKENS_RECEIVER, _amount);
    }

    /// @notice We assume that quoteToken is wrapped native token
    function _transferNative(uint256 _amount) internal {
        IWrappedNativeToken(address(NATIVE_TOKEN)).withdraw(_amount);
        TOKENS_RECEIVER.sendValue(_amount);
    }
}
