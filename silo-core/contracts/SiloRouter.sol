// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {IWrappedNativeToken} from "./interfaces/IWrappedNativeToken.sol";
import {ISilo} from "./interfaces/ISilo.sol";
import {TokenHelper} from "./lib/TokenHelper.sol";

/// @title SiloRouter
/// @notice Silo Router is a utility contract that aims to improve UX. It can batch any number or combination
/// of actions (Deposit, Withdraw, Borrow, Repay) and execute them in a single transaction.
/// @dev SiloRouter requires only first action asset to be approved
/// @custom:security-contact security@silo.finance
contract SiloRouter {
    using SafeERC20 for IERC20;

    // @notice Action types that are supported
    enum ActionType {
        Deposit,
        Mint,
        Repay,
        RepayShares
    }

    struct AnyAction {
        // how much assets or shares do you want to use?
        uint256 amount;
        // are you using Protected, Collateral
        ISilo.CollateralType assetType;
    }

    struct Action {
        // what do you want to do?
        ActionType actionType;
        // which Silo are you interacting with?
        ISilo silo;
        // what asset do you want to use?
        IERC20 asset;
        // options specific for actions
        bytes options;
    }

    /// @dev native asset wrapped token. In case of Ether, it's WETH.
    IWrappedNativeToken public immutable WRAPPED_NATIVE_TOKEN;

    error ApprovalFailed();
    error ERC20TransferFailed();
    error EthTransferFailed();
    error InvalidSilo();

    constructor(address _wrappedNativeToken) {
        TokenHelper.assertAndGetDecimals(_wrappedNativeToken);

        WRAPPED_NATIVE_TOKEN = IWrappedNativeToken(_wrappedNativeToken);
    }

    /// @dev needed for unwrapping WETH
    receive() external payable {
        // `execute` method calls `IWrappedNativeToken.withdraw()`
        // and we need to receive the withdrawn ETH unconditionally
    }

    /// @notice Execute actions
    /// @dev User can bundle any combination and number of actions. It's possible to do multiple deposits,
    /// withdraws etc. For that reason router may need to send multiple tokens back to the user. Combining
    /// Ether and WETH deposits will make this function revert.
    /// @param _actions array of actions to execute
    function execute(Action[] calldata _actions) external payable {
        uint256 len = _actions.length;

        // execute actions
        for (uint256 i = 0; i < len; i++) {
            _executeAction(_actions[i]);
        }

        // send all assets to user
        for (uint256 i = 0; i < len; i++) {
            IERC20 asset = _actions[i].asset;
            uint256 remainingBalance = asset.balanceOf(address(this));

            if (remainingBalance != 0) {
                _sendAsset(asset, remainingBalance);
            }
        }

        // should never have leftover ETH, however
        if (msg.value != 0 && address(this).balance != 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success, EthTransferFailed());
        }
    }

    /// @dev Execute actions
    /// @param _action action to execute, this can be one of many actions in the whole flow
    // solhint-disable-next-line code-complexity
    function _executeAction(Action calldata _action) internal {
        if (_action.actionType == ActionType.Deposit) {
            AnyAction memory data = abi.decode(_action.options, (AnyAction));

            _pullAssetIfNeeded(_action.asset, data.amount);
            _approveIfNeeded(_action.asset, address(_action.silo), data.amount);

            _action.silo.deposit(data.amount, msg.sender, data.assetType);
        } else if (_action.actionType == ActionType.Mint) {
            AnyAction memory data = abi.decode(_action.options, (AnyAction));

            uint256 assetsAmount = _action.silo.previewMint(data.amount);

            _pullAssetIfNeeded(_action.asset, assetsAmount);
            _approveIfNeeded(_action.asset, address(_action.silo), assetsAmount);

            _action.silo.mint(data.amount, msg.sender, data.assetType);
        } else if (_action.actionType == ActionType.Repay) {
            AnyAction memory data = abi.decode(_action.options, (AnyAction));
            _pullAssetIfNeeded(_action.asset, data.amount);
            _approveIfNeeded(_action.asset, address(_action.silo), data.amount);

            _action.silo.repay(data.amount, msg.sender);
        } else if (_action.actionType == ActionType.RepayShares) {
            AnyAction memory data = abi.decode(_action.options, (AnyAction));

            uint256 assetsAmount = _action.silo.previewRepayShares(data.amount);

            _pullAssetIfNeeded(_action.asset, assetsAmount);
            _approveIfNeeded(_action.asset, address(_action.silo), assetsAmount);

            _action.silo.repayShares(data.amount, msg.sender);
        }
    }

    /// @dev Approve Silo to transfer token if current allowance is not enough
    /// @param _asset token to be approved
    /// @param _spender Silo address that spends the token
    /// @param _amount amount of token to be spent
    function _approveIfNeeded(IERC20 _asset, address _spender, uint256 _amount) internal {
        if (_asset.allowance(address(this), _spender) < _amount) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory data) = address(_asset).call(
                abi.encodeCall(IERC20.approve, (_spender, type(uint256).max))
            );

            // Support non-standard tokens that don't return bool
            require(success && (data.length == 0 || abi.decode(data, (bool))), ApprovalFailed());
        }
    }

    /// @dev Transfer funds from msg.sender to this contract if balance is not enough
    /// @param _asset token to be approved
    /// @param _amount amount of token to be spent
    function _pullAssetIfNeeded(IERC20 _asset, uint256 _amount) internal {
        uint256 remainingBalance = _asset.balanceOf(address(this));

        // There can't be an underflow in the subtraction because of the previous check
        _amount = remainingBalance < _amount ? _amount - remainingBalance : 0;

        if (_amount > 0) {
            _pullAsset(_asset, _amount);
        }
    }

    /// @dev Transfer asset from user to router
    /// @param _asset asset address to be transferred
    /// @param _amount amount of asset to be transferred
    function _pullAsset(IERC20 _asset, uint256 _amount) internal {
        if (msg.value != 0 && _asset == WRAPPED_NATIVE_TOKEN) {
            WRAPPED_NATIVE_TOKEN.deposit{value: _amount}();
        } else {
            _asset.safeTransferFrom(msg.sender, address(this), _amount);
        }
    }

    /// @dev Transfer asset from router to user
    /// @param _asset asset address to be transferred
    /// @param _amount amount of asset to be transferred
    function _sendAsset(IERC20 _asset, uint256 _amount) internal {
        if (address(_asset) == address(WRAPPED_NATIVE_TOKEN)) {
            WRAPPED_NATIVE_TOKEN.withdraw(_amount);
            // solhint-disable-next-line avoid-low-level-calls
            (bool success,) = msg.sender.call{value: _amount}("");
            require(success, ERC20TransferFailed());
        } else {
            _asset.safeTransfer(msg.sender, _amount);
        }
    }
}
