import {SiloFactory} from "silo-core/contracts/SiloFactory.sol";

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

contract SiloFactoryHarness is SiloFactory {
    constructor(address _daoFeeReceiver)
        SiloFactory(_daoFeeReceiver)
    {
    }

    function getOwner(uint256 siloID) external view returns (address)
    {
        return _ownerOf(siloID);
    }
}
