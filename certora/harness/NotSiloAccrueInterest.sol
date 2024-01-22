// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {SiloHarness} from "./SiloHarness.sol";

contract NotSiloAccrueInterest is SiloHarness {
    constructor(ISiloFactory _siloFactory) SiloHarness(_siloFactory) {}

    function _accrueInterest()
        internal
        override
        virtual
        returns (uint256 accruedInterest, ISiloConfig.ConfigData memory configData)
    {
        // do not update
    }
}
