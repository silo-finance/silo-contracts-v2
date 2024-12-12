// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

contract ShareDebtToken0 is ShareDebtToken {

    /*
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override 
    {
        // solhint-disable-previous-line ordering
        ShareDebtToken._afterTokenTransfer(_sender, _recipient, _amount);
        uint256 assets = 1000;
        (ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig) =
            silo.config().getConfigs(address(silo));
        ISilo(debtConfig.otherSilo).withdraw(assets, _sender, _sender);
    }
    */
}
