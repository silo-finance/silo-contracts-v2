// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

interface IBankModule {
    function mint(address recipient, uint256 amount) external payable returns (bool);
    function totalSupply(address) external view returns (uint256);
    function metadata (address) external view returns (string memory, string memory, uint8);
}


contract InjectiveTest is Test {
    address public constant BANK_PRECOMPILE = address(0x64);
    address public constant YINJ = 0x2d6E0e0c209D79b43f5d3D62e93D6A9f1e9317BD;
    address public constant BYINJ = 0x913DD99a3326ecaB24A26B817f707CaE07Df7e45;
    uint256 public constant YINJ_TOTAL_SUPPLY = 225177260588439321975142;
    uint256 public constant BYINJ_TOTAL_SUPPLY = 231823129690205125835646;

    address MTS_USDT = 0x88f7F2b685F9692caf8c478f5BADF09eE9B1Cc13;
 address wETH = 0x83A15000b753AC0EeE06D2Cb41a69e76D0D5c7F7;
 address wINJ = 0x0000000088827d2d103ee2d9A6b781773AE03FfB;


    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_INJECTIVE"));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vvv --mt test_Injective_totalSupply
    */
    function test_Injective_totalSupply() public {
        emit log_named_uint("totalSupply YINJ", IBankModule(BANK_PRECOMPILE).totalSupply(YINJ));
        emit log_named_uint("totalSupply BYINJ", IBankModule(BANK_PRECOMPILE).totalSupply(BYINJ));
        emit log_named_uint("totalSupply MTS_USDT", IBankModule(BANK_PRECOMPILE).totalSupply(MTS_USDT));
        emit log_named_uint("totalSupply wINJ", IBankModule(BANK_PRECOMPILE).totalSupply(wINJ));


    }    
}