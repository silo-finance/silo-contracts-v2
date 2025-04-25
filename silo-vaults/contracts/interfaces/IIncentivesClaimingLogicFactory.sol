// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";

/// @title Incentives Claiming Logic Factory interface
interface IIncentivesClaimingLogicFactory {
    /// @notice Returns true if the logic was created in the factory
    /// @param _logic The logic to check
    /// @return createdInFactory True if the logic was created in the factory
    function createdInFactory(IIncentivesClaimingLogic _logic) external view returns (bool createdInFactory);
}
