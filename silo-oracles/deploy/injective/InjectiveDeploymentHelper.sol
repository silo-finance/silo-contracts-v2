// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "../CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {YinjToInjAdapter} from "silo-oracles/contracts/custom/yINJ/YinjToInjAdapter.sol";
import {IYInjPriceOracle} from "silo-oracles/contracts/custom/yINJ/interfaces/IYInjPriceOracle.sol";

interface IBankModule {
    function mint(address recipient, uint256 amount) external payable returns (bool);
    function totalSupply(address) external view returns (uint256);
    function metadata (address) external view returns (string memory, string memory, uint8);
}

contract InjectiveDeploymentHelper is CommonDeploy {
    address public constant BANK_PRECOMPILE = address(0x64);
    address public constant YINJ = 0x2d6E0e0c209D79b43f5d3D62e93D6A9f1e9317BD;
    address public constant BYINJ = 0x913DD99a3326ecaB24A26B817f707CaE07Df7e45;
    uint256 public constant YINJ_TOTAL_SUPPLY = 225177260588439321975142;
    uint256 public constant BYINJ_TOTAL_SUPPLY = 231823129690205125835646;

    // This function helps to bypass the failure of deployment tx simulation.
    function mockBankModule() public {
        vm.mockCall(
            BANK_PRECOMPILE,
            abi.encodeWithSelector(IBankModule.totalSupply.selector, YINJ),
            abi.encode(YINJ_TOTAL_SUPPLY)
        );

        vm.mockCall(
            BANK_PRECOMPILE,
            abi.encodeWithSelector(IBankModule.totalSupply.selector, BYINJ),
            abi.encode(BYINJ_TOTAL_SUPPLY)
        );

        vm.mockCall(
            BANK_PRECOMPILE,
            abi.encodeWithSelector(IBankModule.metadata.selector, BYINJ),
            abi.encode("byINJ", "byINJ", 18)
        );

        vm.mockCall(
            BANK_PRECOMPILE,
            abi.encodeWithSelector(IBankModule.metadata.selector, YINJ),
            abi.encode("yINJ", "yINJ", 18)
        );

        // TODO Validate wINJ token name, symbol and decimals. Explorer is down.
        vm.mockCall(
            BANK_PRECOMPILE,
            abi.encodeWithSelector(IBankModule.metadata.selector, 0x0000000088827d2d103ee2d9A6b781773AE03FfB),
            abi.encode("wINJ", "wINJ", 18)
        );
    }
}
