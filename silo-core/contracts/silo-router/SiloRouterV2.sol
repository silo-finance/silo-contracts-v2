// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Address} from "openzeppelin5/utils/Address.sol";
import {Pausable} from "openzeppelin5/utils/Pausable.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ReentrancyGuard} from "openzeppelin5/utils/ReentrancyGuard.sol";

import {ISiloRouterV2} from "../interfaces/ISiloRouterV2.sol";
import {IUserSiloRouter} from "../interfaces/IUserSiloRouter.sol";
import {UserSiloRouterV2} from "./UserSiloRouterV2.sol";

/// @title SiloRouterV2
/// @custom:security-contact security@silo.finance
/// @notice Silo Router is a utility contract that aims to improve UX. It can batch any number or combination
/// of actions (Deposit, Withdraw, Borrow, Repay) and execute them in a single transaction.
/// @dev SiloRouterV2 requires only first action asset to be approved
/// @dev Caller should ensure that the router balance is empty after multicall.
contract SiloRouterV2 is Pausable, Ownable2Step, ReentrancyGuard, ISiloRouterV2 {
    /// @notice The address of the implementation contract
    address public immutable USER_SILO_ROUTER_IMPL;

    /// @notice Mapping of user to their silo router contract
    mapping(address user => IUserSiloRouter siloRouter) public userSiloRouterContract;

    /// @notice Constructor for the SiloRouterV2 contract
    /// @param _initialOwner The address of the initial owner
    constructor (address _initialOwner) Ownable(_initialOwner) {
        USER_SILO_ROUTER_IMPL = address(new UserSiloRouterV2(address(this)));
    }

    /// @inheritdoc ISiloRouterV2
    function multicall(bytes[] calldata data)
        external
        virtual
        payable
        nonReentrant
        whenNotPaused
        returns (bytes[] memory results)
    {
        IUserSiloRouter userSiloRouter = _resolveSiloRouterContract();
        results = userSiloRouter.multicall{value: msg.value}(data, msg.sender);
    }

    /// @inheritdoc ISiloRouterV2
    function pause() external virtual onlyOwner {
        _pause();
    }

    /// @inheritdoc ISiloRouterV2
    function unpause() external virtual onlyOwner {
        _unpause();
    }

    /// @inheritdoc ISiloRouterV2
    function predictUserSiloRouterContract(address _user) external view returns (IUserSiloRouter siloRouter) {
        siloRouter = IUserSiloRouter(Clones.predictDeterministicAddress({
            implementation: USER_SILO_ROUTER_IMPL,
            salt: _getSalt(_user),
            deployer: address(this)
        }));
    }

    /// @dev This function is used to get the silo router contract for a user.
    /// If the silo router contract does not exist, it will be created.
    /// @return siloRouter
    function _resolveSiloRouterContract() internal returns (IUserSiloRouter siloRouter) {
        siloRouter = userSiloRouterContract[msg.sender];

        if (address(siloRouter) != address(0)) {
            return siloRouter;
        }

        siloRouter = IUserSiloRouter(Clones.cloneDeterministic({
            implementation: USER_SILO_ROUTER_IMPL,
            salt: _getSalt(msg.sender)
        }));

        userSiloRouterContract[msg.sender] = siloRouter;

        emit SiloRouterContractCreated(msg.sender, address(siloRouter));
    }

    /// @dev This function is used to get the salt for a user.
    function _getSalt(address _user) internal pure returns (bytes32) {
        return bytes32(bytes20(_user));
    }
}
