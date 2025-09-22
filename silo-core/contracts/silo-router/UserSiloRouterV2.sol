// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Address} from "openzeppelin5/utils/Address.sol";
import {Pausable} from "openzeppelin5/utils/Pausable.sol";

import {IUserSiloRouter} from "silo-core/contracts/interfaces/IUserSiloRouter.sol";
import {SiloRouterV2Implementation} from "silo-core/contracts/silo-router/SiloRouterV2Implementation.sol";

/// @title UserSiloRouterV2
/// @custom:security-contact security@silo.finance
/// @notice Silo Router is a utility contract that aims to improve UX. It can batch any number or combination
/// of actions (Deposit, Withdraw, Borrow, Repay) and execute them in a single transaction.
/// @dev SiloRouterV2 requires only first action asset to be approved
/// @dev Caller should ensure that the router balance is empty after multicall.
contract UserSiloRouterV2 is IUserSiloRouter {
    /// @notice The address of the implementation contract
    address public immutable IMPLEMENTATION;

    /// @notice The address of the silo router
    address public immutable SILO_ROUTER;

    /// @notice Transient variable to store the msg.sender
    address public transient msgSender;

    /// @notice Constructor for the SiloRouterV2 contract
    /// @param _siloRouter The address of the silo router
    constructor (address _siloRouter) {
        // expect implementation to not work with storage
        IMPLEMENTATION = address(new SiloRouterV2Implementation());
        SILO_ROUTER = _siloRouter;
    }

    modifier onlySiloRouter() {
        require(msg.sender == SILO_ROUTER, OnlySiloRouter());
        _;
    }

    modifier whenNotPaused() {
        require(!Pausable(address(SILO_ROUTER)).paused(), Paused());
        _;
    }

    /// @dev Needed for unwrapping native tokens
    receive() external whenNotPaused payable {
        // `multicall` method may call `IWrappedNativeToken.withdraw()`
        // and we need to receive the withdrawn native token unconditionally
    }

    /// @inheritdoc IUserSiloRouter
    function multicall(bytes[] calldata data, address _msgSender)
        external
        virtual
        onlySiloRouter
        payable
        returns (bytes[] memory results)
    {
        msgSender = _msgSender;

        results = new bytes[](data.length);

        for (uint256 i = 0; i < data.length; i++) {
            // expect implementation not to use `msg.value`
            results[i] = Address.functionDelegateCall(IMPLEMENTATION, data[i]);
        }

        msgSender = address(0);
    }
}
