// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Permit} from "openzeppelin5/token/ERC20/extensions/IERC20Permit.sol";

interface ISiloToken is IERC20, IERC20Metadata, IERC20Permit {
    function mint(address _to, uint256 _amount) external;
    function burn(uint256 _amount) external;
    function transferOwnership(address newOwner) external;
    function owner() external view returns (address);
}
