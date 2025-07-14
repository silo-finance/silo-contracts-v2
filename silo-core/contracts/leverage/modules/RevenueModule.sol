// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ILeverageRouter} from "silo-core/contracts/interfaces/ILeverageRouter.sol";
import {TransientReentrancy} from "../../hooks/_common/TransientReentrancy.sol";

/// @title Revenue Module for Leverage Operations
/// @notice This contract collects and distributes revenue from leveraged operations.
abstract contract RevenueModule is TransientReentrancy {
    using SafeERC20 for IERC20;

    /// @notice Fee base constant (1e18 represents 100%)
    uint256 public immutable FEE_PRECISION;

    /// @notice The router of this leverage contract
    ILeverageRouter public immutable ROUTER;

    /// @notice Emitted when leverage revenue is withdrawn
    /// @param token Address of the token
    /// @param revenue Amount withdrawn
    /// @param receiver Address that received the funds
    event LeverageRevenue(address indexed token, uint256 revenue, address indexed receiver);

    /// @notice Emitted when tokens are rescued
    /// @param token Address of the token
    /// @param amount Amount rescued
    event TokensRescued(address indexed token, uint256 amount);

    /// @dev Thrown when there is no tokens to rescue
    error EmptyBalance(address token);

    /// @dev Thrown when the caller is not the router
    error OnlyRouter();

    /// @dev Thrown when revenue receiver is not set
    error ReceiverNotSet();

    /// @dev Thrown when caller is not the leverage user
    error OnlyLeverageUser();

    /// @dev Thrown when native token transfer fails
    error NativeTokenTransferFailed();

    constructor(address _router, uint256 _feePrecision) {
        ROUTER = ILeverageRouter(_router);
        FEE_PRECISION = _feePrecision;
    }

    modifier onlyRouter() {
        require(msg.sender == address(ROUTER), OnlyRouter());
        _;
    }

    modifier onlyLeverageUser() {
        require(ROUTER.predictUserLeverageContract(msg.sender) == address(this), OnlyLeverageUser());
        _;
    }

    /// @notice We do not expect anyone else to engage with a contract except the user for whom it was created.
    /// @dev Use this function to rescue native tokens
    function rescueNativeTokens() external nonReentrant onlyLeverageUser {
        uint256 balance = address(this).balance;
        require(balance != 0, EmptyBalance(address(0)));

        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, NativeTokenTransferFailed());
        
        emit TokensRescued(address(0), balance);
    }

    /// @notice We do not expect anyone else to engage with a contract except the user for whom it was created.
    /// @param _tokens List of tokens to rescue
    function rescueTokens(IERC20[] calldata _tokens) external nonReentrant onlyLeverageUser {
        for (uint256 i; i < _tokens.length; i++) {
            rescueTokens(_tokens[i]);
        }
    }

    /// @notice We do not expect anyone else to engage with a contract except the user for whom it was created.
    /// @param _token ERC20 token to rescue
    function rescueTokens(IERC20 _token) public nonReentrant onlyLeverageUser {
        uint256 balance = _token.balanceOf(address(this));
        require(balance != 0, EmptyBalance(address(_token)));

        address receiver = msg.sender;

        _token.safeTransfer(receiver, balance);
        emit TokensRescued(address(_token), balance);
    }

    /// @notice Calculates the leverage fee for a given amount
    /// @dev Will always return at least 1 if fee > 0 and calculation rounds down
    /// @param _amount The amount to calculate the fee for
    /// @return leverageFeeAmount The calculated fee amount
    function calculateLeverageFee(uint256 _amount) public virtual view returns (uint256 leverageFeeAmount) {
        uint256 fee = ROUTER.leverageFee();
        if (fee == 0) return 0;

        leverageFeeAmount = Math.mulDiv(_amount, fee, FEE_PRECISION, Math.Rounding.Ceil);
        if (leverageFeeAmount == 0) leverageFeeAmount = 1;
    }

    function _payLeverageFee(address _token, uint256 _leverageFee) internal virtual {
        if (_leverageFee != 0) IERC20(_token).safeTransfer(ROUTER.revenueReceiver(), _leverageFee);
    }
}
