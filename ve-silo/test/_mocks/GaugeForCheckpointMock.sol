// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

contract GaugeForCheckpointMock {
    mapping(address user => uint256 numberOfCheckpoints) public userCheckpoints;

    // solhint-disable-next-line func-name-mixedcase
    function user_checkpoint(address _user) external returns (bool) {
        userCheckpoints[_user]++;

        return true;
    }
}
