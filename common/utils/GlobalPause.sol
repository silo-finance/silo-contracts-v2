// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";

import {Ownable1and2Steps, Ownable2Step} from "common/access/Ownable1and2Steps.sol";
import {IPausable} from "./interfaces/IPausable.sol";
import {IGnosisSafeLike} from "./interfaces/IGnosisSafeLike.sol";
import {IGlobalPause} from "./interfaces/IGlobalPause.sol";

contract GlobalPause is Ownable1and2Steps, IGlobalPause {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The list of contracts to pause and unpause
    EnumerableSet.AddressSet private _contracts;

    /// @notice The list of accounts who can pause and unpause contracts
    EnumerableSet.AddressSet private _authorizedToPause;

    /// @dev Modifier to check if the caller is a signer of the multisig contract
    modifier onlySigner() {
        require(isSigner(msg.sender), Forbidden());
        _;
    }

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
        _contracts.add(_contract);
        emit ContractAdded(_contract);
    }

    /// @inheritdoc IGlobalPause
    function removeContract(address _contract) external onlyOwner {
        _contracts.remove(_contract);
        emit ContractRemoved(_contract);
    }

    /// @inheritdoc IGlobalPause
    function grantAuthorization(address _account) external onlyOwner {
        _authorizedToPause.add(_account);
        emit Authorized(_account);
    }

    /// @inheritdoc IGlobalPause
    function revokeAuthorization(address _account) external onlyOwner {
        _authorizedToPause.remove(_account);
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
    function transferOwnershipAll(address _newOwner) external onlyOwner {
        uint256 length = _contracts.length();

        for (uint256 i = 0; i < length; i++) {
            address contractAddr = _contracts.at(i);
            Ownable2Step(contractAddr).transferOwnership(_newOwner);
            emit OwnershipTransferStarted(contractAddr, _newOwner);
        }
    }

    /// @inheritdoc IGlobalPause
    function allContracts() external view returns (address[] memory) {
        return _contracts.values();
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
        IPausable(_contract).unpause();
        emit Unpaused(_contract);
    }
}
