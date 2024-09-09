// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IVeDelegation} from "@balancer-labs/v2-interfaces/contracts/liquidity-mining/IVeDelegation.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

interface IVotingEscrowDelegationProxy {
    function setDelegation(IVeDelegation delegation) external;
    function killDelegation() external;
    function getDelegationImplementation() external view returns (IVeDelegation);
    function getVotingEscrow() external view returns (IERC20);
    function adjustedBalanceOf(address user) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
