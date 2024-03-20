// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISilo} from "../interfaces/ISilo.sol";

interface IShareDebtToken {
    event PositionTypeSet(address indexed user, ISilo.PositionType positionType);

    function positionType(address _owner) external view returns (ISilo.PositionType);
    function balanceOfAndPositionType(address _owner) external view returns (uint256, ISilo.PositionType);
}
