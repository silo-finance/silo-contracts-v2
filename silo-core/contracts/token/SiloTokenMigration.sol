// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Pausable} from "openzeppelin5/utils/Pausable.sol";
import {TransientReentrancy} from "silo-core/contracts/utils/hook-receivers/_common/TransientReentrancy.sol";

contract SiloTokenMigration is Ownable2Step, Pausable, TransientReentrancy {
    IERC20 immutable OLD_SILO;
    IERC20 immutable NEW_SILO;

    event Migrated(address indexed owner, uint256 amount);

    constructor(IERC20 _oldSilo, IERC20 _newSilo) Ownable(msg.sender) {
        OLD_SILO = _oldSilo;
        NEW_SILO = _newSilo;
    }

    /// @notice It will burn your all "old" SIlo tokens and mint new one with 1:1 ratio.
    /// @return amount Amount of migrated tokens
    function migrate() external whenNotPaused nonReentrant returns (uint256 amount) {
        amount = IERC20(OLD_SILO).balanceOf(msg.sender);

        IERC20(OLD_SILO).transferFrom(msg.sender, address(this), amount);
        IERC20(OLD_SILO).burn(amount);
        IERC20(NEW_SILO).mint(amount);
        IERC20(NEW_SILO).transfer(msg.sender, amount);

        emit Migrated(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // TODO do we need this one or only transferSiloOwnership?
    /**
     * @dev Leaves the `NEW_SILO` contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceSiloOwnership() public virtual onlyOwner {
        NEW_SILO.transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the `NEW_SILO` contract to a new account (`_newOwner`).
     * Can only be called by the current owner.
     */
    function transferSiloOwnership(address _newOwner) public virtual onlyOwner {
        NEW_SILO.transferOwnership(_newOwner);
    }
}
