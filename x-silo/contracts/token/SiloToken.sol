// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "openzeppelin5/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Capped} from "openzeppelin5/token/ERC20/extensions/ERC20Capped.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Pausable} from "openzeppelin5/utils/Pausable.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

/// @title Silo Token V2.
contract SiloToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Capped, Pausable, Ownable2Step {
    /// @dev Reverts in constructor for invalid address of $SILO V1 token.
    error InvalidSiloV1Address();

    /// @notice $SILO V1 token address used for token migration.
    ERC20Burnable public immutable SILO_V1; // solhint-disable-line var-name-mixedcase

    constructor(address _initialOwner, ERC20Burnable _siloV1)
        ERC20("Silo Token", "SILO")
        ERC20Permit("Silo Token")
        ERC20Capped(1_000_000_000e18)
        Ownable(_initialOwner)
    {
        require(Strings.equal(_siloV1.symbol(), "Silo"), InvalidSiloV1Address());

        SILO_V1 = _siloV1;
    }

    /// @notice Exchange $SILO V1 tokens for the same amount of $SILO V2. V1 tokens will be burned.
    /// @param to Recipient address.
    /// @param amount Amount to mint.
    function mint(address to, uint256 amount) external virtual whenNotPaused {
        SILO_V1.burnFrom(msg.sender, amount);
        _mint(to, amount);
    }

    /// @notice Contract owner can pause the migration from $SILO V1. Token transfers are not pausable.
    function pause() external virtual onlyOwner {
        _pause();
    }

    /// @notice Contract owner can unpause the migration from $SILO V1.
    function unpause() external virtual onlyOwner {
        _unpause();
    }

    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(ERC20, ERC20Capped)
    {
        ERC20Capped._update(from, to, value);
    }
}
