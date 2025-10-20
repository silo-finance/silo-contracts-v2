// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.28;

interface ISiloIncentivesControllerGetters {
    function NOTIFIER() external view returns (address); // solhint-disable-line func-name-mixedcase
    function SHARE_TOKEN() external view returns (address); // solhint-disable-line func-name-mixedcase
}
