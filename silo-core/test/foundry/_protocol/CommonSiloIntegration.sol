// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {SiloContracts} from "./SiloContracts.sol";

import {
    IBalancerVaultLike as Vault
} from "ve-silo/contracts/fees-distribution/interfaces/IBalancerVaultLike.sol";

abstract contract CommonSiloIntegration is IntegrationTest, SiloContracts {
    address internal _bob = makeAddr("Bob");
    address internal _alice = makeAddr("Alice");
    address internal _deployer;

    Vault internal _balancerVault;
    IERC20 internal _wethToken;
    IERC20 internal _siloToken;
    IERC20 internal _usdcToken;

    constructor() {
        _wethToken = IERC20(getAddress(AddrKey.WETH));
        _usdcToken = IERC20(getAddress(AddrKey.USDC));
        _siloToken = IERC20(getAddress(SILO_TOKEN));
        _balancerVault = Vault(getAddress(AddrKey.BALANCER_VAULT));

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);
    }
}
