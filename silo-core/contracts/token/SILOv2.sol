// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "openzeppelin5/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Pausable} from "openzeppelin5/utils/Pausable.sol";

/// @title SILOv2 token.
contract SILOv2 is ERC20Burnable, ERC20Permit, Ownable2Step, Pausable {
    /// @notice $SILO token address used for $SILOv2 migration.
    ERC20Burnable public immutable SILO_V1; // solhint-disable-line var-name-mixedcase

    constructor(address _initialOwner, ERC20Burnable _siloV1)
        ERC20("SILOv2", "SiloGovernanceTokenV2")
        ERC20Permit("SILOv2")
        Ownable(_initialOwner)
    {
        SILO_V1 = _siloV1;
    }

    /// @notice Exchange $SILO tokens for the same amount of $SILOv2. $SILO tokens will be burned.
    /// @param to Recipient address.
    /// @param amount Amount to mint.
    function mint(address to, uint256 amount) external virtual whenNotPaused {
        SILO_V1.burnFrom(_msgSender(), amount);
        _mint(to, amount);
    }

    /// @notice Contract owner can pause the migration from $SILO. Token transfers are not pausable.
    function pause() external virtual onlyOwner {
        _pause();
    }

    /// @notice Contract owner can unpause the migration from $SILO.
    function unpause() external virtual onlyOwner {
        _unpause();
    }
}
