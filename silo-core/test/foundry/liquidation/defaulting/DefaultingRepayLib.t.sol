// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {DefaultingRepayLib} from "silo-core/contracts/hooks/defaulting/DefaultingRepayLib.sol";
import {Actions} from "silo-core/contracts/lib/Actions.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {ShareTokenLib} from "silo-core/contracts/lib/ShareTokenLib.sol";

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";


import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";

contract ShareDebtTokenMock is ShareDebtToken {
    function mockIt(ISilo _silo) external {
        ShareTokenLib.__ShareToken_init({
            _silo: _silo, 
            _hookReceiver: address(0), 
            _tokenType: uint24(Hook.DEBT_TOKEN)
        });
    }

    function overrideSilo(ISilo _silo) external {
        ShareTokenLib.getShareTokenStorage().silo = _silo;
    }
}

contract SiloAndConfigMock {
    ShareDebtTokenMock public immutable debtShareToken;
    MintableToken public immutable debtAsset;

    constructor() {
        debtShareToken = new ShareDebtTokenMock();
        debtAsset = new MintableToken(18);
        debtAsset.setOnDemand(true);
    }

    function config() external view returns (ISiloConfig) {
        return ISiloConfig(address(this));
    }
    
    function turnOnReentrancyProtection() external pure {
    }

    function turnOffReentrancyProtection() external pure {
    }

    function accrueInterestForSilo(address /* _silo */) external pure {
    }

    function getDebtShareTokenAndAsset(address /* _silo */) external view returns (address, address) {
        return (address(debtShareToken), address(debtAsset));
    }
}

contract LibImpl {
    function init(address _silo) external {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        $.siloConfig = ISiloConfig(_silo);
        // $.silo = ISilo(_silo);
    }

    function createDebtForBorrower(address _borrower, uint256 _assets) external {
        ShareDebtTokenMock(address(getDebtShareToken())).overrideSilo(ISilo(address(this)));
        IShareToken(getDebtShareToken()).mint(_borrower, _borrower, _assets * 1e3);

        SiloStorageLib.getSiloStorage().totalAssets[ISilo.AssetType.Debt] = _assets;
    }

    function debtShareTokenSilo() public view returns (ISilo) {
        return IShareToken(getDebtShareToken()).silo();
    }

    function getDebtShareToken() public view returns (address debtShareToken) {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
         (debtShareToken,) = $.siloConfig.getDebtShareTokenAndAsset(address(this));
    }
}

contract DefaultingRepayLibImpl is LibImpl {
    function actionsRepay(uint256 _assets, uint256 _shares, address _borrower, address _repayer) external returns (uint256 assets, uint256 shares) {
        ShareDebtTokenMock(address(getDebtShareToken())).overrideSilo(ISilo(address(this)));
        return DefaultingRepayLib.actionsRepay(_assets, _shares, _borrower, _repayer);
    }
}

contract ActionsLibImpl is LibImpl {
    function repay(uint256 _assets, uint256 _shares, address _borrower, address _repayer) external returns (uint256 assets, uint256 shares) {
        ShareDebtTokenMock(address(getDebtShareToken())).overrideSilo(ISilo(address(this)));
        return Actions.repay(_assets, _shares, _borrower, _repayer);
    }
}


contract DefaultingRepayLibTest is Test {
    address borrower = makeAddr("borrower");

    DefaultingRepayLibImpl defaultingRepayLibImpl = new DefaultingRepayLibImpl();
    ActionsLibImpl actionsLibImpl = new ActionsLibImpl();

    SiloAndConfigMock siloAndConfigMockActions = new SiloAndConfigMock();
    SiloAndConfigMock siloAndConfigMockDefaulting = new SiloAndConfigMock();

    function setUp() public {
        siloAndConfigMockActions.debtShareToken().mockIt(ISilo(address(siloAndConfigMockActions)));
        siloAndConfigMockDefaulting.debtShareToken().mockIt(ISilo(address(siloAndConfigMockDefaulting)));

        defaultingRepayLibImpl.init(address(siloAndConfigMockActions));
        actionsLibImpl.init(address(siloAndConfigMockDefaulting));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_dafaulting_actionsRepay -vvv
    */
    function test_dafaulting_actionsRepay() public {
        uint256 assets = 100e6;
        uint256 shares = 0;

        _createDebtForBorrower(assets);

        (uint256 assetsRepaid1, uint256 sharesRepaid1) = defaultingRepayLibImpl.actionsRepay(assets, shares, borrower, borrower);
        (uint256 assetsRepaid2, uint256 sharesRepaid2) = actionsLibImpl.repay(assets, shares, borrower, borrower);

        assertEq(assetsRepaid1, assetsRepaid2, "[assets] expect same result because repay is a copy");
        assertEq(sharesRepaid1, sharesRepaid2, "[shares] expect same result because repay is a copy");
    }

    function _createDebtForBorrower(uint256 _assets) internal {
        defaultingRepayLibImpl.createDebtForBorrower(borrower, _assets);
        actionsLibImpl.createDebtForBorrower(borrower, _assets);
    }
}
