// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {WhitelistComplianceResolver} from "silo-core/contracts/hooks/compliance/resolvers/WhitelistComplianceResolver.sol";
import {IWhitelistComplianceResolver} from "silo-core/contracts/interfaces/compliance/IWhitelistComplianceResolver.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/WhitelistComplianceResolverDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract WhitelistComplianceResolverDeploy is CommonDeploy {
    function run() public returns (IWhitelistComplianceResolver whitelistResolver) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        whitelistResolver = IWhitelistComplianceResolver(address(new WhitelistComplianceResolver()));

        vm.stopBroadcast();

        _registerDeployment(address(whitelistResolver), SiloCoreContracts.WHITELIST_COMPLIANCE_RESOLVER);

        return whitelistResolver;
    }
}
