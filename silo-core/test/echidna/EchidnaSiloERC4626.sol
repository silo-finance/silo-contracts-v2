pragma solidity ^0.8.0;

import {Deployers} from "./utils/Deployers.sol";
import {ISilo, Silo} from "silo-core/contracts/Silo.sol";
import {ISiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {ISiloFactory, SiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {CryticERC4626PropertyTests} from "properties/ERC4626/ERC4626PropertyTests.sol";
import {TestERC20Token} from "properties/ERC4626/util/TestERC20Token.sol";

/*
./silo-core/scripts/echidnaBefore.sh
SOLC_VERSION=0.8.22 echidna silo-core/test/echidna/EchidnaSiloERC4626.sol --contract EchidnaSiloERC4626 --config silo-core/test/echidna/erc4626.yaml --workers 10
*/
contract EchidnaSiloERC4626 is CryticERC4626PropertyTests, Deployers {
    ISiloConfig siloConfig;
    event AssertionFailed(string msg, bytes reason);
    event AssertionFailed(string msg, string reason);

    constructor() payable {
        ve_setUp(1706745600);
        core_setUp(address(this)); // fee receiver

        TestERC20Token _asset0 = new TestERC20Token("Test Token0", "TT0", 18);
        TestERC20Token _asset1 = new TestERC20Token("Test Token1", "TT1", 18);
        _initData(address(_asset0), address(_asset1));

        // deploy silo
        siloConfig = siloFactory.createSilo(siloData["MOCK"]);
        (address _vault0, /* address _vault1 */) = siloConfig.getSilos();

        initialize(address(_vault0), address(_asset0), false);
    }
}
