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

/// @notice LiquidationHelper IS NOT PART OF THE PROTOCOL.
contract LiquidationHelper is ILiquidationHelper, IERC3156FlashBorrower, DexSwap {
    using Address for address payable;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    /// @dev token receiver will get all rewards from liquidation, does not matter who will execute tx
    address payable public immutable TOKENS_RECEIVER;

    address public immutable NATIVE_TOKEN;

    uint256 private transient _withdrawCollateral;
    uint256 private transient _repayDebtAssets;

    error NoDebtToCover();
    error STokenNotSupported();

    /// @param _nativeToken address of wrapped native blockchain token eg. WETH on Ethereum
    /// @param _exchangeProxy exchange address, where to send swap data on liquidation
    /// @param _tokensReceiver all leftover tokens (debt and collateral) will be send to this address after liquidation
    constructor (
        address _nativeToken,
        address _exchangeProxy,
        address payable _tokensReceiver
    ) DexSwap(_exchangeProxy) {
        NATIVE_TOKEN = _nativeToken;
        EXCHANGE_PROXY = _exchangeProxy;
        TOKENS_RECEIVER = _tokensReceiver;
    }

    /// @dev for now we does not support liquidation with sTokens
    /// @dev for non profitable liquidation we will revert
    function executeLiquidation(
        ISilo _flashLoanFrom,
        address _debtAsset,
        uint256 _maxDebtToCover,
        LiquidationData calldata _liquidation,
        DexSwapInput[] calldata _swapsInputs0x
    ) external returns (uint256 withdrawCollateral, uint256 repayDebtAssets) {
        require(_maxDebtToCover != 0, NoDebtToCover());

        _flashLoanFrom.flashLoan(this, _debtAsset, _maxDebtToCover, abi.encode(_liquidation, _swapsInputs0x));
        IERC20(_debtAsset).approve(address(_flashLoanFrom), 0);

        withdrawCollateral = _withdrawCollateral;
        repayDebtAssets = _repayDebtAssets;
    }

    function onFlashLoan(
        address /* _initiator */,
        address _debtAsset,
        uint256 _maxDebtToCover,
        uint256 _fee,
        bytes calldata _data
    )
        external
        returns (bytes32)
    {
        (
            LiquidationData memory _liquidation,
            DexSwapInput[] memory _swapInputs
        ) = abi.decode(_data, (LiquidationData, DexSwapInput[]));

        IERC20(_debtAsset).approve(address(_liquidation.hook), _maxDebtToCover);

        bool receiveSToken;

        (
            _withdrawCollateral, _repayDebtAssets
        ) = _liquidation.hook.liquidationCall(
            _liquidation.collateralAsset, _debtAsset, _liquidation.user, _maxDebtToCover, receiveSToken
        );

        IERC20(_debtAsset).approve(address(_liquidation.hook), 0);

        if (_liquidation.collateralAsset == _debtAsset) {
            uint256 balance = IERC20(_liquidation.collateralAsset).balanceOf(address(this));
            // bad debt is not supported, we will get underflow on bad debt
            _transferToReceiver(_liquidation.collateralAsset, balance - (_maxDebtToCover + _fee));
        } else {
            uint256 debtBalance = IERC20(_debtAsset).balanceOf(address(this));
            uint256 loanWithFee = _maxDebtToCover + _fee;

            if (loanWithFee < debtBalance) {
                unchecked {
                    // safe because of `if (loanWithFee < debtBalance)`
                    _transferToReceiver(_debtAsset, debtBalance - loanWithFee);
                }
            }

            _executeSwap(_swapInputs); // part of collateral => _maxDebtToCover + _fee
            uint256 balance = IERC20(_liquidation.collateralAsset).balanceOf(address(this));
            _transferToReceiver(_liquidation.collateralAsset, balance);
        }

        IERC20(_debtAsset).approve(msg.sender, _maxDebtToCover + _fee);

        return _FLASHLOAN_CALLBACK;
    }

    function _executeSwap(DexSwapInput[] memory _swapInputs) internal {
        for (uint256 i; i < _swapInputs.length; i++) {
            fillQuote(_swapInputs[i].sellToken, _swapInputs[i].allowanceTarget, _swapInputs[i].swapCallData);
        }
    }

    function _transferToReceiver(address _asset, uint256 _amount) internal {
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
