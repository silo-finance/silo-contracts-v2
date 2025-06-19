// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {IWrappedNativeToken} from "silo-core/contracts/interfaces/IWrappedNativeToken.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC4626OracleFactoryDeploy} from "silo-oracles/deploy/erc4626/ERC4626OracleFactoryDeploy.sol";
import {ERC4626OracleFactory} from "silo-oracles/contracts/erc4626/ERC4626OracleFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

interface Price {
    function latestAnswer() external view returns (int);
}
/*
FOUNDRY_PROFILE=oracles forge test -vv --ffi --mc ERC4626PriceManipulationWmetaUSD
*/
contract ERC4626PriceManipulationWmetaUSD is IntegrationTest {
    address internal _attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_SONIC"), 34853072);
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --ffi --mt test_wmetaUSD_donation -vv
    */
    function test_wmetaUSD_donation() public {
        _getPrice();
        _dealAsset();
        _getPrice();
    }

    function _dealAsset() internal {
        address metaWhale = 0x1597E4B7cF6D2877A1d690b6088668afDb045763;
        IERC4626 metaUSD = IERC4626(0x1111111199558661Bf7Ff27b4F1623dC6b91Aa3e);
        IERC4626 wmetaUSD = IERC4626(0xAaAaaAAac311D0572Bffb4772fe985A750E88805);

        uint256 amount = metaUSD.balanceOf(metaWhale);

        vm.startPrank(metaWhale);
        metaUSD.transfer(address(this), amount);
        vm.stopPrank();

        // transfer protection
        vm.warp(block.timestamp + 10);
        vm.roll(block.number + 10);

        metaUSD.transfer(address(wmetaUSD), amount);
    }

    function _getPrice() internal returns (uint256 price) {
        address priceAggregator = 0x440A6bf579069Fa4e7C3C9fe634B34D2C78C584c;
        int priceInt = Price(priceAggregator).latestAnswer();
        emit log_named_int("latestAnswer", priceInt);
    }
}
