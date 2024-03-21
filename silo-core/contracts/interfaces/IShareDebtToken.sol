// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISilo} from "../interfaces/ISilo.sol";

interface IShareDebtToken {
    event PositionTypeSet(address indexed owner, uint256 positionType);

    function positionType(address _owner) external view returns (uint256);
    function getBalanceAndPosition(address _owner) external view returns (uint256, uint256);
}
