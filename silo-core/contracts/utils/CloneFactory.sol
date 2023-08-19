// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {CountersUpgradeable} from "openzeppelin-contracts-upgradeable/utils/CountersUpgradeable.sol";
import {ClonesUpgradeable} from  "openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

contract CloneFactory {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _cloneId;

    mapping(uint256 cloneId => address cloneAddress) public idToAddress;

    event NewClone(uint256 indexed cloneId, address cloneAddress, address implementation);

    error ZeroAddress();
    error InitRevert(bytes errorData);

    function getNextCloneId() external view returns (uint256) {
        return _cloneId.current();
    }

    /// @notice Deploys minimal proxy contract for oracle
    /// @param _implementation address of implementation contract
    /// @param _initData optional initiation data for cloned contract. Must encode function signature and params.
    /// @return cloneAddress deployed clone address
    function deployClone(address _implementation, bytes memory _initData) public returns (address cloneAddress) {
        if (_implementation == address(0)) revert ZeroAddress();

        cloneAddress = ClonesUpgradeable.clone(_implementation);

        // initialize oracle
        if (_initData.length > 0) {
            // solhint-disable avoid-low-level-calls
            (bool success, bytes memory returndata) = cloneAddress.call(_initData);
            if (!success) revert InitRevert(returndata);
        }

        uint256 nextCloneId = _cloneId.current();
        _cloneId.increment();

        idToAddress[nextCloneId] = cloneAddress;

        emit NewClone(nextCloneId, cloneAddress, _implementation);
    }
}
