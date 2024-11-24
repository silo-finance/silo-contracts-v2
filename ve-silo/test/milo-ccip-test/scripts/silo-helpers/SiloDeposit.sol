// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

interface IWETH {
    function deposit() external payable;
    function approve(address spender, uint256 amount) external returns (bool);
}

/**
FOUNDRY_PROFILE=ve-silo-test \
    SILO=0x0000000000000000000000000000000000000000 \
    forge script ve-silo/test/milo-ccip-test/scripts/silo-helpers/SiloDeposit.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8546
 */
contract SiloDeposit is Script {
    function run() external returns (uint256 shares) {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);
        address silo = VmLib.vm().envAddress("SILO");
        address weth = AddrLib.getAddress(AddrKey.WETH);

        uint256 balance = deployer.balance;
        uint256 depositAmount = balance / 2;

        vm.startBroadcast(deployerPrivateKey);

        IWETH(weth).deposit{value: depositAmount}();
        IWETH(weth).approve(silo, depositAmount);

        shares = ISilo(silo).deposit(depositAmount, deployer, ISilo.CollateralType.Collateral);

        vm.stopBroadcast();
    }
}
