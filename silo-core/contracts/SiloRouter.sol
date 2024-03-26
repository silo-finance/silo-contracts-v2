// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import {IPermit2, ISignatureTransfer} from "./interfaces/permit2/IPermit2.sol";
import {IWrappedNativeToken} from "./interfaces/IWrappedNativeToken.sol";
import {ISilo} from "./interfaces/ISilo.sol";
import {ILeverageBorrower} from "./interfaces/ILeverageBorrower.sol";

import {TokenHelper} from "./lib/TokenHelper.sol";

/// @title SiloRouter
/// @notice Silo Router is a utility contract that aims to improve UX. It can batch any number or combination
/// of actions (Deposit, Withdraw, Borrow, Repay) and execute them in a single transaction.
/// @dev SiloRouter requires only first action asset to be approved
/// @custom:security-contact security@silo.finance
contract SiloRouter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // @notice Action types that are supported
    enum ActionType {
        Deposit,
        Mint,
        Withdraw,
        Redeem,
        Borrow,
        BorrowShares,
        Repay,
        RepayShares,
        Transition,
        Leverage
    }

    struct PermitData {
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }

    struct BorrowOptions {
        // how much assets or shares do you want to use?
        uint256 amount;
        bool sameToken;
    }

    struct LeverageOptions {
        // how much assets or shares do you want to use?
        uint256 amount;
        ILeverageBorrower leverageBorrower;
        bool sameToken;
        // optional data that will be send to leverageBorrower
        bytes data;
    }

    struct AnyAction {
        // how much assets or shares do you want to use?
        uint256 amount;
        // receiver of leveraged funds that will sell them on DEXes
        ILeverageBorrower receiver;
        // optional data for leverage
        bytes data;
        // are you using Protected, Collateral or Debt?
        ISilo.AssetType assetType;
        // optional Permit2
        PermitData permit;
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

    // @dev native asset wrapped token. In case of Ether, it's WETH.
    // solhint-disable-next-line var-name-mixedcase
    IWrappedNativeToken public immutable WRAPPED_NATIVE_TOKEN;
    // solhint-disable-next-line var-name-mixedcase
    IPermit2 public immutable PERMIT2;

    error ApprovalFailed();
    error ERC20TransferFailed();
    error EthTransferFailed();
    error InvalidSilo();
    error UnsupportedAction();

    constructor(address _wrappedNativeToken, address _permit2) {
        TokenHelper.assertAndGetDecimals(_wrappedNativeToken);

        WRAPPED_NATIVE_TOKEN = IWrappedNativeToken(_wrappedNativeToken);
        PERMIT2 = IPermit2(_permit2);
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
    function execute(Action[] calldata _actions) external payable nonReentrant {
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
            if (!success) revert EthTransferFailed();
        }
    }

    /// @dev Execute actions
    /// @param _action action to execute, this can be one of many actions in the whole flow
    // solhint-disable-next-line code-complexity
    function _executeAction(Action calldata _action) internal {
        if (_action.actionType == ActionType.Deposit) {
            AnyAction memory data = abi.decode(_action.options, (AnyAction));

            _pullAssetIfNeeded(_action.asset, data.amount, data.permit);
            _approveIfNeeded(_action.asset, address(_action.silo), data.amount);

            _action.silo.deposit(data.amount, msg.sender, data.assetType);
        } else if (_action.actionType == ActionType.Mint) {
            AnyAction memory data = abi.decode(_action.options, (AnyAction));

            _pullAssetIfNeeded(_action.asset, data.amount, data.permit);
            _approveIfNeeded(_action.asset, address(_action.silo), data.amount);

            _action.silo.mint(data.amount, msg.sender, data.assetType);
        } else if (_action.actionType == ActionType.Withdraw) {
            AnyAction memory data = abi.decode(_action.options, (AnyAction));
            _action.silo.withdraw(data.amount, address(this), msg.sender, data.assetType);
        } else if (_action.actionType == ActionType.Redeem) {
            AnyAction memory data = abi.decode(_action.options, (AnyAction));
            _action.silo.redeem(data.amount, address(this), msg.sender, data.assetType);
        } else if (_action.actionType == ActionType.Borrow) {
            BorrowOptions memory data = abi.decode(_action.options, (BorrowOptions));
            _action.silo.borrow(data.amount, address(this), msg.sender, data.sameToken);
        } else if (_action.actionType == ActionType.BorrowShares) {
            BorrowOptions memory data = abi.decode(_action.options, (BorrowOptions));
            _action.silo.borrowShares(data.amount, address(this), msg.sender, data.sameToken);
        } else if (_action.actionType == ActionType.Repay) {
            AnyAction memory data = abi.decode(_action.options, (AnyAction));
            _pullAssetIfNeeded(_action.asset, data.amount, data.permit);
            _approveIfNeeded(_action.asset, address(_action.silo), data.amount);

            _action.silo.repay(data.amount, msg.sender);
        } else if (_action.actionType == ActionType.RepayShares) {
            AnyAction memory data = abi.decode(_action.options, (AnyAction));
            _pullAssetIfNeeded(_action.asset, data.amount, data.permit);
            _approveIfNeeded(_action.asset, address(_action.silo), data.amount);

            _action.silo.repayShares(data.amount, msg.sender);
        } else if (_action.actionType == ActionType.Transition) {
            AnyAction memory data = abi.decode(_action.options, (AnyAction));
            _action.silo.transitionCollateral(data.amount, msg.sender, data.assetType);
        } else if (_action.actionType == ActionType.Leverage) {
            LeverageOptions memory data = abi.decode(_action.options, (LeverageOptions));
            _action.silo.leverage(data.amount, data.leverageBorrower, msg.sender, data.sameToken, data.data);
        } else {
            revert UnsupportedAction();
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
            if (!success || !(data.length == 0 || abi.decode(data, (bool)))) {
                revert ApprovalFailed();
            }
        }
    }

    /// @dev Transfer funds from msg.sender to this contract if balance is not enough
    /// @param _asset token to be approved
    /// @param _amount amount of token to be spent
    function _pullAssetIfNeeded(IERC20 _asset, uint256 _amount, PermitData memory _permit) internal {
        uint256 remainingBalance = _asset.balanceOf(address(this));

        // There can't be an underflow in the subtraction because of the previous check
        _amount = remainingBalance < _amount ? _amount - remainingBalance : 0;

        if (_amount > 0) {
            if (_permit.signature.length > 0) {
                PERMIT2.permitTransferFrom(
                    // The permit message.
                    ISignatureTransfer.PermitTransferFrom({
                        permitted: ISignatureTransfer.TokenPermissions({
                            token: address(_asset),
                            amount: _permit.amount
                        }),
                        nonce: _permit.nonce,
                        deadline: _permit.deadline
                    }),
                    // The transfer recipient and amount.
                    ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: _amount}),
                    // The owner of the tokens, which must also be
                    // the signer of the message, otherwise this call
                    // will fail.
                    msg.sender,
                    // The packed signature that was the result of signing
                    // the EIP712 hash of `permit`.
                    _permit.signature
                );
            } else {
                _pullAsset(_asset, _amount);
            }
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
            if (!success) revert ERC20TransferFailed();
        } else {
            _asset.safeTransfer(msg.sender, _amount);
        }
    }
}
