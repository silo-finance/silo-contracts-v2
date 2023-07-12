// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IExtendedOwnable {
    function changeManager(address _manager) external;
    function owner() external view returns (address);
    function manager() external view returns (address);
}
