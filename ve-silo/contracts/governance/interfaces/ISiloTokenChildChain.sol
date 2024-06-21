// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Permit} from "openzeppelin5/token/ERC20/extensions/IERC20Permit.sol";
import {IAccessControl} from "openzeppelin5/access/IAccessControl.sol";

interface ISiloTokenChildChain is IERC20, IERC20Metadata, IERC20Permit, IAccessControl {
    function mint(address _to, uint256 _amount) external;
    function burn(uint256 _amount) external;
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function BRIDGE_ROLE() external view returns (bytes32);
}
