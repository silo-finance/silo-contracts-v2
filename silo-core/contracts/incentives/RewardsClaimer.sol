// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";


interface IClaimOnBehalf {
    enum CallType {
        Call, // default
        Delegatecall
    }

    function callOnBehalf(address _target, uint256 _value, CallType _callType, bytes calldata _input)
        external
        virtual
        payable
        returns (bool success, bytes memory result);
}

/**
 * @title RewardsClaimer - midleman contract to claim rewards for vault
 * @notice it would be easy to make this contract generic and use it to call any external contract with any method
 * @author Silo.finance
 */
contract RewardsClaimer is Ownable2Step {
    struct ClaimData {
        address target;
        bytes data;
    }

    error InvalidData();
    error EmptyData();

    /// @dev `data` that allows to claim reward on `target` contract.
    mapping(address target => bytes memory data) claimingData;

    /// @dev if we will define array of targets, we can create method `claimRewardsForVault()` without arguments
    /// to prevent out of gas, we can do this:
    /// 1. set gas limit and break loop
    /// save index and start from it next time
    address[] targets;

    constructor(address _owner) Ownable(_owner) {}

    function setClaimingData(address _target, bytes calldata _data) external onlyOwner {
        require(_data.length >= 8, InvalidData());

        claimingData[_target] = _data;
    }

    /// @dev this is entry method, anyone can call it
    /// @param _vault
    function claimRewardsForVault(IClaimOnBehalf _vault, address[] calldata _targets) external {
        ClaimData[] memory claimData = new ClaimData[](_targets.length);

        for (uint256 i; i < _targets.length; i++) {
            address target = _targets[i];
            bytes memory data = claimingData[target];

            require(data.length != 0, EmptyData());

            claimData[i] = ClaimData(target, data);
        }

        // vault must accept this call
        _vault.callOnBehalf(
            address(this),
            0,
            IClaimOnBehalf.CallType.Delegatecall,
            abi.encodeWithSelector(RewardsClaimer.claimOnBehalf.selector, claimData)
        );
    }

    function claimOnBehalfOfVault(ClaimData[] calldata _claimDatas) external {
        for (uint256 i; i < _claimDatas.length; i++) {
            _claimDatas[i].target.call(_claimDatas[i].data);
        }
    }
}
