// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "openzeppelin5/access/AccessControl.sol";
import {ERC20Permit, ERC20} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";
import {Context} from "openzeppelin5/utils/Context.sol";

contract MiloTokenChildChain is ERC20Permit, AccessControl {
    /// @dev Dedicate a role for the bridge contract to mint tokens
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    constructor() ERC20("Milo", "MILO") ERC20Permit("Milo") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function mint(address _to, uint256 _amount) external onlyRole(BRIDGE_ROLE) {
        _mint(_to, _amount);
    }

    function burn(uint256 _amount) external {
        _burn(_msgSender(), _amount);
    }
}
