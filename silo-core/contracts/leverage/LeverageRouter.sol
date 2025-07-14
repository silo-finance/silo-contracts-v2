// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {Pausable} from "openzeppelin5/utils/Pausable.sol";
import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {ILeverageRouter} from "silo-core/contracts/interfaces/ILeverageRouter.sol";
import {ILeverageUsingSiloFlashloan} from "silo-core/contracts/interfaces/ILeverageUsingSiloFlashloan.sol";
import {LeverageRouterRevenueModule} from "silo-core/contracts/leverage/modules/LeverageRouterRevenueModule.sol";

import {
    LeverageUsingSiloFlashloanWithGeneralSwap
} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";

/// @notice This contract is used to route leverage operations to the appropriate leverage contract.
contract LeverageRouter is LeverageRouterRevenueModule, Pausable {
    /// @notice The implementation of the leverage contract
    address public immutable LEVERAGE_IMPLEMENTATION;
    /// @notice Mapping of user to their leverage contract
    mapping(address user => ILeverageUsingSiloFlashloan leverageContract) public userLeverageContract;

    /// @param _initialOwner The initial owner of the contract
    /// @param _native The native token address
    constructor(address _initialOwner, address _native) Ownable(_initialOwner) {
        LEVERAGE_IMPLEMENTATION = address(new LeverageUsingSiloFlashloanWithGeneralSwap({
            _router: address(this),
            _native: _native,
            _feePrecision: FEE_PRECISION
        }));
    }

    /// @inheritdoc ILeverageRouter
    function openLeveragePosition(
        ILeverageUsingSiloFlashloan.FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        ILeverageUsingSiloFlashloan.DepositArgs calldata _depositArgs
    ) external whenNotPaused payable {
        ILeverageUsingSiloFlashloan leverageContract = _getLeverageContract();

        leverageContract.openLeveragePosition{value: msg.value}({
            _msgSender: msg.sender,
            _flashArgs: _flashArgs,
            _swapArgs: _swapArgs,
            _depositArgs: _depositArgs
        });
    }

    /// @inheritdoc ILeverageRouter
    function openLeveragePositionPermit(
        ILeverageUsingSiloFlashloan.FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        ILeverageUsingSiloFlashloan.DepositArgs calldata _depositArgs,
        ILeverageUsingSiloFlashloan.Permit calldata _depositAllowance
    ) external whenNotPaused {
        ILeverageUsingSiloFlashloan leverageContract = _getLeverageContract();

        leverageContract.openLeveragePositionPermit({
            _msgSender: msg.sender,
            _flashArgs: _flashArgs,
            _swapArgs: _swapArgs,
            _depositArgs: _depositArgs,
            _depositAllowance: _depositAllowance
        
        });
    }

    /// @inheritdoc ILeverageRouter
    function closeLeveragePosition(
        bytes calldata _swapArgs,
        ILeverageUsingSiloFlashloan.CloseLeverageArgs calldata _closeLeverageArgs
    ) external whenNotPaused {
        ILeverageUsingSiloFlashloan leverageContract = userLeverageContract[msg.sender];

        leverageContract.closeLeveragePosition({
            _msgSender: msg.sender,
            _swapArgs: _swapArgs,
            _closeLeverageArgs: _closeLeverageArgs
        });
    }

    /// @inheritdoc ILeverageRouter
    function closeLeveragePositionPermit(
        bytes calldata _swapArgs,
        ILeverageUsingSiloFlashloan.CloseLeverageArgs calldata _closeLeverageArgs,
        ILeverageUsingSiloFlashloan.Permit calldata _withdrawAllowance
    ) external whenNotPaused {
        ILeverageUsingSiloFlashloan leverageContract = userLeverageContract[msg.sender];

        leverageContract.closeLeveragePositionPermit({
            _msgSender: msg.sender,
            _swapArgs: _swapArgs,
            _closeLeverageArgs: _closeLeverageArgs,
            _withdrawAllowance: _withdrawAllowance
        });
    }

    /// @inheritdoc ILeverageRouter
    function pause() external onlyOwner {
        _pause();
    }

    /// @inheritdoc ILeverageRouter
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc ILeverageRouter
    function predictUserLeverageContract(address _user) external view returns (address leverageContract) {
        leverageContract = Clones.predictDeterministicAddress({
            implementation: LEVERAGE_IMPLEMENTATION,
            salt: _getSalt(_user),
            deployer: address(this)
        });
    }

    /// @dev This function is used to get the leverage contract for a user.
    /// If the leverage contract does not exist, it will be created.
    /// @return leverageContract
    function _getLeverageContract() internal returns (ILeverageUsingSiloFlashloan leverageContract) {
        leverageContract = userLeverageContract[msg.sender];

        if (address(leverageContract) != address(0)) {
            return leverageContract;
        }

        leverageContract = ILeverageUsingSiloFlashloan(Clones.cloneDeterministic({
            implementation: LEVERAGE_IMPLEMENTATION,
            salt: _getSalt(msg.sender)
        }));

        userLeverageContract[msg.sender] = leverageContract;

        emit LeverageContractCreated(msg.sender, address(leverageContract));
    }

    /// @dev This function is used to get the salt for a user.
    function _getSalt(address _user) internal pure returns (bytes32) {
        return bytes32(bytes20(_user));
    }
}
