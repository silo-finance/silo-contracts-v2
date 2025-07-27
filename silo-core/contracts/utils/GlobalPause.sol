// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";

import {Ownable1and2Steps, Ownable2Step} from "common/access/Ownable1and2Steps.sol";
import {IPausable} from "common/utils/interfaces/IPausable.sol";
import {IGnosisSafeLike} from "common/utils/interfaces/IGnosisSafeLike.sol";
import {IGlobalPause} from "common/utils/interfaces/IGlobalPause.sol";

contract GlobalPause is Ownable1and2Steps, IGlobalPause {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The list of contracts to pause and unpause
    EnumerableSet.AddressSet private _contracts;

    /// @notice The list of accounts who can pause and unpause contracts
    EnumerableSet.AddressSet private _authorizedToPause;

    /// @dev Modifier to check if the caller is a signer of the multisig contract or a manager
    modifier onlyAuthorized() {
        require(
            isSigner(msg.sender) || _authorizedToPause.contains(msg.sender) || msg.sender == owner(),
            Forbidden()
        );
        _;
    }

    /// @param _multisig The multisig contract which owners are allowed to pause and unpause contracts
    constructor(address _multisig) Ownable1and2Steps(_multisig) {}

    /// @inheritdoc IGlobalPause
    function pauseAll() external onlyAuthorized {
        uint256 length = _contracts.length();

        for (uint256 i = 0; i < length; i++) {
            _pause(_contracts.at(i));
        }
    }

    /// @inheritdoc IGlobalPause
    function unpauseAll() external onlyAuthorized {
        uint256 length = _contracts.length();

        for (uint256 i = 0; i < length; i++) {
            _unpause(_contracts.at(i));
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
    function addContract(address _contract) external onlyAuthorized {
        require(_contracts.add(_contract), FailedToAdd());
        emit ContractAdded(_contract);
    }

    /// @inheritdoc IGlobalPause
    function removeContract(address _contract) external onlyOwner {
        require(_contracts.remove(_contract), FailedToRemove());
        emit ContractRemoved(_contract);
    }

    /// @inheritdoc IGlobalPause
    function grantAuthorization(address _account) external onlyOwner {
        require(_authorizedToPause.add(_account), FailedToAdd());
        emit Authorized(_account);
    }

    /// @inheritdoc IGlobalPause
    function revokeAuthorization(address _account) external onlyOwner {
        require(_authorizedToPause.remove(_account), FailedToRemove());
        emit Unauthorized(_account);
    }

    /// @inheritdoc IGlobalPause
    function acceptOwnership(address _contract) external onlyAuthorized {
        Ownable2Step(_contract).acceptOwnership();
        emit OwnershipAccepted(_contract);
    }

    /// @inheritdoc IGlobalPause
    function transferOwnershipFrom(address _contract, address _newOwner) external onlyOwner {
        Ownable2Step(_contract).transferOwnership(_newOwner);
        emit OwnershipTransferStarted(_contract, _newOwner);
    }

    /// @inheritdoc IGlobalPause
    function allContracts() external view returns (address[] memory) {
        return _contracts.values();
    }

    /// @inheritdoc IGlobalPause
    function authorizedToPause() external view returns (address[] memory) {
        return _authorizedToPause.values();
    }

    /// @notice Renounce ownership of the contract and ensure that _contracts and _authorizedToPause are empty
    function renounceOwnership() public virtual override {
        require(_contracts.length() == 0, ContractsNotEmpty());
        require(_authorizedToPause.length() == 0, AuthorizedToPauseNotEmpty());

        super.renounceOwnership();
    }

    /// @inheritdoc IGlobalPause
    function isSigner(address _account) public view returns (bool result) {
        address[] memory signers = IGnosisSafeLike(owner()).getOwners();

        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == _account) {
                return true;
            }
        }
    }

    /// @inheritdoc IGlobalPause
    function getAllContractsPauseStatus() external view returns (ContractPauseStatus[] memory result) {
        uint256 length = _contracts.length();
        result = new ContractPauseStatus[](length);

        for (uint256 i = 0; i < length; i++) {
            address contractAddress = _contracts.at(i);
            bool isPaused = IPausable(contractAddress).paused();

            result[i] = ContractPauseStatus({contractAddress: contractAddress, isPaused: isPaused});
        }
    }

    /// @dev Pause a contract
    /// @param _contract The contract to pause
    function _pause(address _contract) internal {
        // Using try/catch to avoid blockage of the `pauseAll` fn
        // in case contract permissions were revoked and contract was not removed.
        try IPausable(_contract).pause() {
            emit Paused(_contract);
        } catch {
            emit FailedToPause(_contract);
        }
    }

    /// @dev Unpause a contract
    /// @param _contract The contract to unpause
    function _unpause(address _contract) internal {
        // Using try/catch to avoid blockage of the `unpauseAll` fn
        try IPausable(_contract).unpause() {
            emit Unpaused(_contract);
        } catch {
            emit FailedToUnpause(_contract);
        }
    }
}
