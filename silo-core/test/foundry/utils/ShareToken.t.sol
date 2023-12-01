// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ClonesUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "silo-core/contracts/lib/SiloERC4626Lib.sol";
import "silo-core/contracts/utils/ShareDebtToken.sol";
import "silo-core/contracts/interfaces/ISilo.sol";
import "silo-core/contracts/interfaces/ISiloConfig.sol";

contract Token {
    uint8 public immutable decimals;

    constructor(uint8 _decimals) {
        decimals = _decimals;
    }
}

/*
forge test -vv --mc ShareTokenTest
*/
contract ShareTokenTest is Test {
    /*
    forge test -vv --mt test_ShareToken_decimals
    */
    function test_ShareToken_decimals() public {
        uint8 decimals = 8;
        Token token = new Token(decimals);
        ShareDebtToken sToken = ShareDebtToken(ClonesUpgradeable.clone(address(new ShareDebtToken())));
        ISilo silo = ISilo(address(1));
        address hook = address(0);
        sToken.initialize(silo, hook);

        address siloConfig = address(2);
        ISiloConfig.ConfigData memory configData;
        configData.token = address(token);

        bytes memory data = abi.encodeWithSelector(ISilo.config.selector);
        vm.mockCall(address(silo), data, abi.encode(siloConfig));
        vm.expectCall(address(silo), data);

        bytes memory data2 = abi.encodeWithSelector(ISiloConfig.getConfig.selector, address(silo));
        vm.mockCall(siloConfig, data2, abi.encode(configData));
        vm.expectCall(siloConfig, data2);

        assertEq(10 ** (sToken.decimals() - token.decimals()), SiloMathLib._DECIMALS_OFFSET_POW, "expect valid offset");
    }
}
