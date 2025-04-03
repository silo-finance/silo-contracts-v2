// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Address} from "openzeppelin5/utils/Address.sol";
import {Pausable} from "openzeppelin5/utils/Pausable.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ReentrancyGuard} from "openzeppelin5/utils/ReentrancyGuard.sol";

import {ISiloRouter} from "../interfaces/ISiloRouter.sol";

/// @title SiloRouter
/// @custom:security-contact security@silo.finance
/// @notice Silo Router is a utility contract that aims to improve UX. It can batch any number or combination
/// of actions (Deposit, Withdraw, Borrow, Repay) and execute them in a single transaction.
/// @dev SiloRouter requires only first action asset to be approved
/// @dev Caller should ensure that the router balance is empty after multicall.
contract SiloRouter is Pausable, Ownable2Step, ReentrancyGuard, ISiloRouter {
    /// @notice The address of the implementation contract
    address public immutable IMPLEMENTATION;

    /// @notice Constructor for the SiloRouter contract
    /// @param _initialOwner The address of the initial owner
    /// @param _implementation The address of the implementation contract
    constructor (address _initialOwner, address _implementation) Ownable(_initialOwner) {
        // expect implementation to not work with storage
        IMPLEMENTATION = _implementation;
    }

    /// @dev Needed for unwrapping native tokens
    receive() external whenNotPaused payable {
        // `multicall` method may call `IWrappedNativeToken.withdraw()`
        // and we need to receive the withdrawn native token unconditionally
    }

    /// @inheritdoc ISiloRouter
    function multicall(bytes[] calldata data)
        external
        virtual
        payable
        nonReentrant
        whenNotPaused
        returns (bytes[] memory results)
    {
        results = new bytes[](data.length);

        for (uint256 i = 0; i < data.length; i++) {
            // expect implementation not to use `msg.value`
            results[i] = Address.functionDelegateCall(IMPLEMENTATION, data[i]);
        }

        return results;
    }

    /// @inheritdoc ISiloRouter
    function pause() external virtual onlyOwner {
        _pause();
    }

    /// @inheritdoc ISiloRouter
    function unpause() external virtual onlyOwner {
        _unpause();
    }
}
