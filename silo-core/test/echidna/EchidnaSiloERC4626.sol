// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Deployers} from "./utils/Deployers.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {ISiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {ShareProtectedCollateralToken} from "silo-core/contracts/utils/ShareProtectedCollateralToken.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {CryticERC4626PropertyTests} from "properties/ERC4626/ERC4626PropertyTests.sol";
import {TestERC20Token} from "properties/ERC4626/util/TestERC20Token.sol";

/*
./silo-core/scripts/echidnaBefore.sh
SOLC_VERSION=0.8.24 echidna silo-core/test/echidna/EchidnaSiloERC4626.sol --contract EchidnaSiloERC4626 --config silo-core/test/echidna/erc4626.yaml --workers 10
*/
contract EchidnaSiloERC4626 is CryticERC4626PropertyTests, Deployers {
    ISiloConfig siloConfig;
    event AssertionFailed(string msg, bytes reason);
    event AssertionFailed(string msg, string reason);

    constructor() payable {
        core_setUp(address(this)); // fee receiver

        TestERC20Token _asset0 = new TestERC20Token("Test Token0", "TT0", 18);
        TestERC20Token _asset1 = new TestERC20Token("Test Token1", "TT1", 18);
        _initData(address(_asset0), address(_asset1));

        address siloImpl = address(new Silo(siloFactory));
        address shareProtectedCollateralTokenImpl = address(new ShareProtectedCollateralToken());
        address shareDebtTokenImpl = address(new ShareDebtToken());

        // deploy silo config
        siloConfig = _deploySiloConfig(
            siloData["MOCK"],
            siloImpl,
            shareProtectedCollateralTokenImpl,
            shareDebtTokenImpl
        );

        // deploy silo
        siloFactory.createSilo(
            siloConfig,
            siloImpl,
            shareProtectedCollateralTokenImpl,
            shareDebtTokenImpl,
            siloData["MOCK"].deployer,
            msg.sender
        );

        (address _vault0, /* address _vault1 */) = siloConfig.getSilos();

        initialize(address(_vault0), address(_asset0), false);
    }
}
