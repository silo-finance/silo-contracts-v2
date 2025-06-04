// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "x-silo/deploy/CommonDeploy.sol";
import {XSiloContracts} from "x-silo/common/XSiloContracts.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {ERC20Burnable} from "openzeppelin5/token/ERC20/extensions/ERC20Burnable.sol";
import {SiloToken} from "x-silo/contracts/token/SiloToken.sol";

/**
    FOUNDRY_PROFILE=x_silo \
        forge script x-silo/deploy/token/SiloTokenDeploy.s.sol \
        --ffi --rpc-url $RPC_MAINNET --broadcast --verify

    FOUNDRY_PROFILE=x_silo ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY forge verify-contract --constructor-args \
        $(cast abi-encode “constructor(address, address)” <owner_address>  <silo_token_address>) \
        <contract_address> SiloToken
 */
contract SiloTokenDeploy is CommonDeploy {
    function run() public returns (address token) {
        require(
            block.chainid == ChainsLib.ANVIL_CHAIN_ID || block.chainid == ChainsLib.MAINNET_CHAIN_ID,
            "wrong chain"
        );

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        
        ERC20Burnable siloTokenV1 = ERC20Burnable(AddrLib.getAddressSafe(ChainsLib.chainAlias(), "SILO"));
        address owner = AddrLib.getAddressSafe(ChainsLib.chainAlias(), "NEW_SILO_TOKEN_OWNER");

        vm.startBroadcast(deployerPrivateKey);

        token = address(new SiloToken(owner, siloTokenV1));

        vm.stopBroadcast();

        _registerDeployment(token, XSiloContracts.SILO_TOKEN);
    }
}
