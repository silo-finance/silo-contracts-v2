// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Address} from "openzeppelin5/utils/Address.sol";
import {PausableUpgradeable} from "openzeppelin5-upgradeable/utils/PausableUpgradeable.sol";
import {Ownable2StepUpgradeable} from "openzeppelin5-upgradeable//access/Ownable2StepUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin5-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {ISiloRouter} from "../interfaces/ISiloRouter.sol";

/// @title SiloRouter
/// @notice Silo Router is a utility contract that aims to improve UX. It can batch any number or combination
/// of actions (Deposit, Withdraw, Borrow, Repay) and execute them in a single transaction.
/// @dev SiloRouter requires only first action asset to be approved
/// @custom:security-contact security@silo.finance
contract SiloRouter is PausableUpgradeable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable, ISiloRouter {
    /// @notice The address of the implementation contract
    address public immutable IMPLEMENTATION;

    /// @notice Constructor for the SiloRouter contract
    /// @param _initialOwner The address of the initial owner
    /// @param _implementation The address of the implementation contract
    constructor (address _initialOwner, address _implementation) initializer {
        __Ownable_init(_initialOwner);

        IMPLEMENTATION = _implementation;
    }

    /// @dev needed for unwrapping native tokens
    receive() external whenNotPaused payable {
        // `execute` method calls `IWrappedNativeToken.withdraw()`
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
