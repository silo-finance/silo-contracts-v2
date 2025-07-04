// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";

import {IPausable} from "./interfaces/IPausable.sol";
import {IGnosisSafeLike} from "./interfaces/IGnosisSafeLike.sol";
import {IOwnableLike} from "./interfaces/IOwnableLike.sol";

contract GlobalPause is Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The multisig contract which owners are allowed to pause and unpause contracts
    IGnosisSafeLike public multisig;

    /// @notice The list of contracts to pause and unpause
    EnumerableSet.AddressSet public contracts;

    /// @notice The list of accounts who can pause and unpause contracts
    EnumerableSet.AddressSet public authorizedToPause;

    /// @dev Modifier to check if the caller is a signer of the multisig contract
    modifier onlySigner() {
        require(_isSigner(msg.sender), Unauthorized());
        _;
    }

    /// @dev Modifier to check if the caller is a signer of the multisig contract or a manager
    modifier onlyAuthorized() {
        require(_isSigner(msg.sender) || authorizedToPause.contains(msg.sender), Unauthorized());
        _;
    }

    /// @param _multisig The multisig contract which owners are allowed to pause and unpause contracts
    constructor(address _multisig) {
        multisig = IGnosisSafeLike(_multisig);
    }

    /// @inheritdoc IGlobalPause
    function pauseAll() external onlyAuthorized {
        uint256 length = contracts.length();

        for (uint256 i = 0; i < length; i++) {
            _pause(contracts.at(i));
        }
    }

    /// @inheritdoc IGlobalPause
    function unpauseAll() external onlyAuthorized {
        uint256 length = contracts.length();

        for (uint256 i = 0; i < length; i++) {
            _unpause(contracts.at(i));
        }
    }

    /// @inheritdoc IGlobalPause
    function pause(address _contract) external onlyAuthorized {
        _pause(_contract);
    }

    /// @inheritdoc IGlobalPause
    function unpause(address _contract) external onlyAuthorized {
        _unpause(_contract);
    }

    /// @inheritdoc IGlobalPause
    function addContract(address _contract) external onlySigner {
        require(IOwnableLike(_contract).owner() == address(this), GlobalPauseIsNotAnOwner(_contract));

        contracts.add(_contract);
        emit ContractAdded(_contract);
    }

    /// @inheritdoc IGlobalPause
    function removeContract(address _contract) external onlySigner {
        contracts.remove(_contract);
        emit ContractRemoved(_contract);
    }

    /// @inheritdoc IGlobalPause
    function grantAuthorization(address _account) external onlySigner {
        authorizedToPause.add(_account);
        emit Authorized(_account);
    }

    /// @inheritdoc IGlobalPause
    function revokeAuthorization(address _account) external onlySigner {
        authorizedToPause.remove(_account);
        emit Unauthorized(_account);
    }

    /// @inheritdoc IGlobalPause
    function acceptOwnership(address _contract) external onlySigner {
        IOwnableLike(_contract).acceptOwnership();
        emit OwnershipAccepted(_contract);
    }

    /// @inheritdoc IGlobalPause
    function transferOwnership(address _contract, address _newOwner) external onlySigner {
        IOwnableLike(_contract).transferOwnership(_newOwner);
        emit OwnershipTransferStarted(_contract, _newOwner);
    }

    /// @inheritdoc IGlobalPause
    function allContracts() external view returns (address[] memory) {
        return contracts.values();
    }

    /// @dev Pause a contract
    /// @param _contract The contract to pause
    function _pause(address _contract) internal {
        // Sanity check to avoid blockage of the `pauseAll` fn
        // in case contract ownership was transferred and contract was not removed.
        if (IOwnableLike(_contract).owner() != address(this)) return;
        IPausable(_contract).pause();
        emit Paused(_contract);
    }

    /// @dev Unpause a contract
    /// @param _contract The contract to unpause
    function _unpause(address _contract) internal {
        IPausable(_contract).unpause();
        emit Unpaused(_contract);
    }

    function _isSigner(address _account) internal view returns (bool isSigner) {
        address[] memory signers = multisig.getOwners();

        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == _account) {
                returns true;
            }
        }
    }
}
