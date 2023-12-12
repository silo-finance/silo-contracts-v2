// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Silo, ILeverageBorrower, ISiloFactory} from "silo-core/contracts/Silo.sol";

contract SiloLeverageNonReentrant is Silo {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory) {}

    function leverage(uint256, ILeverageBorrower, address, bytes calldata)
        external
        override
        leverageNonReentrant
        returns (uint256 shares)
    {
        shares = 0;

        // Inputs don't matter. We only need to verify reentrancy protection.
        // Expect to revert with `LeverageReentrancyGuard.LeverageReentrancyCall`
        Silo(address(this)).deposit({_assets: 0, _receiver: address(0)});
    }
}
