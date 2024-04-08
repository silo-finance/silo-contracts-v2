// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Silo, ILeverageBorrower, ISiloFactory} from "silo-core/contracts/Silo.sol";

contract SiloLeverageNonReentrant is Silo {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory) {}

    function leverage(uint256, ILeverageBorrower, address, bool, bytes calldata)
        external
        override
        xNonReentrant(Silo(address(this)).config())
        returns (uint256 shares)
    {
        shares = 0;

        // Inputs don't matter. We only need to verify reentrancy protection.
        // Expect to revert with `ISiloConfig.XReentrantCall.selector`
        Silo(address(this)).deposit({_assets: 0, _receiver: address(0)});
    }
}
