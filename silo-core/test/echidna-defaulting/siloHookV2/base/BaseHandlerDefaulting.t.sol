// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {Strings} from "openzeppelin5/utils/Strings.sol";
import {BaseHandler} from "silo-core/test/invariants/base/BaseHandler.t.sol";
import {DefaultBeforeAfterHooks} from "silo-core/test/invariants/hooks/DefaultBeforeAfterHooks.t.sol";

/// @title BaseHandler
/// @notice Contains common logic for all handlers
/// @dev inherits all suite assertions since per action assertions are implmenteds in the handlers
contract BaseHandlerDefaulting is BaseHandler {
    function _getOtherSilo(address _silo) internal view returns (address otherSilo) {
        (address silo0, address silo1) = ISilo(_silo).config().getSilos();
        otherSilo = silo0 == _silo ? silo1 : silo0;
    }

    function _defaultHooksBefore(address silo) internal virtual override {
        super._defaultHooksBefore(silo);

        address actor = _getRandomActor(0);
        rewardsBalanceBefore[actor] = gauge.getRewardsBalance(actor, _getImmediateProgramNames());
    }

    // function _defaultHooksAfter(address silo) internal override {
    //     super._defaultHooksAfter(silo);
    // }

    function _getProgramNames() internal view returns (string[] memory names) {
        names = new string[](2);
        names[0] = Strings.toHexString(address(vault0));

        (address protectedShareToken,,) = siloConfig.getShareTokens(address(vault0));
        names[1] = Strings.toHexString(protectedShareToken);
    }
}
