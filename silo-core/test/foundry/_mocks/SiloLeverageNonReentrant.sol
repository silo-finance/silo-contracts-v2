// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Silo, ILeverageBorrower, ISiloFactory, ISiloConfig} from "silo-core/contracts/Silo.sol";
import {CrossEntrancy} from "silo-core/contracts/lib/CrossEntrancy.sol";

contract SiloLeverageNonReentrant is Silo {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory) {}

    function leverage(uint256, ILeverageBorrower, address, bool, bytes calldata)
        external
        override
        returns (uint256 shares)
    {
        _sharedStorage.siloConfig.crossNonReentrantBefore(CrossEntrancy.ENTERED_FROM_LEVERAGE);
        shares = 0;

        // Inputs don't matter. We only need to verify reentrancy protection.
        // Expect to revert with `ISiloConfig.CrossReentrantCall.selector`
        Silo(payable(address(this))).borrow({_assets: 1, _borrower: address(0), _receiver: address(0), _sameAsset: false});
    }

    function forceConfigSetup(ISiloConfig _siloConfig) external {
        _sharedStorage.siloConfig = _siloConfig;
    }
}
