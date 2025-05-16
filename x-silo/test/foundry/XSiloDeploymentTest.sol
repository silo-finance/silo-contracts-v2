// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";

import {XSiloAndStreamDeploy} from "x-silo/deploy/XSiloAndStreamDeploy.s.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {XSilo} from "x-silo/contracts/XSilo.sol";
import {Stream} from "x-silo/contracts/modules/Stream.sol";

/*
 FOUNDRY_PROFILE=x_silo forge test --ffi --mc XSiloDeploymentTest -vv
*/
contract XSiloDeploymentTest is Test {
    ERC20Mock public siloToken;
    XSilo public xSilo;
    Stream public stream;

    address public dao = makeAddr("dao");

    function setUp() public {
        AddrLib.init();

        siloToken = new ERC20Mock();
        AddrLib.setAddress(AddrKey.SILO_TOKEN_V2, address(siloToken));
        AddrLib.setAddress(AddrKey.DAO, dao);

        XSiloAndStreamDeploy deploy = new XSiloAndStreamDeploy();
        deploy.disableDeploymentsSync();
        (xSilo, stream) = deploy.run();
    }

    function test_deployment() public view {
        assertEq(address(xSilo.stream()), address(stream), "stream");
        assertEq(address(xSilo.notificationReceiver()), address(0), "notificationReceiver");
        assertEq(xSilo.owner(), dao, "owner");
        assertEq(xSilo.asset(), address(siloToken), "asset");
        assertEq(xSilo.totalAssets(), 0, "totalAssets");

        assertEq(stream.BENEFICIARY(), address(xSilo), "beneficiary");
        assertEq(stream.REWARD_ASSET(), address(siloToken), "rewardAsset");
        assertEq(stream.emissionPerSecond(), 0, "emissionPerSecond");
        assertEq(stream.distributionEnd(), block.timestamp, "distributionEnd");
        assertEq(stream.lastUpdateTimestamp(), block.timestamp, "lastUpdateTimestamp");
    }
}
