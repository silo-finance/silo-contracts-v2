// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.28;

interface ISiloIncentivesControllerGetters {
    function NOTIFIER() external view returns (address);
    function SHARE_TOKEN() external view returns (address);
}
