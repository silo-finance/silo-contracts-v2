// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IPendleRewardsClaimer} from "silo-core/contracts/interfaces/IPendleRewardsClaimer.sol";
import {IPendleMarketLike} from "silo-core/contracts/interfaces/IPendleMarketLike.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {IGaugeLike as IGauge} from "silo-core/contracts/interfaces/IGaugeLike.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {PendleRewardsClaimer} from "silo-core/contracts/hooks/PendleRewardsClaimer.sol";

import {
    ISiloIncentivesControllerGaugeLikeFactory
} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IDistributionManager} from "silo-core/contracts/incentives/interfaces/IDistributionManager.sol";

import {SiloLittleHelper} from  "../../../_common/SiloLittleHelper.sol";
import {TransferOwnership} from  "../../../_common/TransferOwnership.sol";

// FOUNDRY_PROFILE=core_test forge test --ffi --mc PendleRewardsClaimerTest -vv
contract PendleRewardsClaimerTest is SiloLittleHelper, Test, TransferOwnership {
    uint256 internal constant _BLOCK_TO_FORK = 22518257;

    address internal _dao = makeAddr("DAO");
    address internal _depositor = 0xf06e212f3d021842f1C8c2De4b9dd04945717aDd;
    address internal _rewardToken = 0x808507121B80c02388fAd14726482e061B8da827;
    address internal _lptWhale = 0x6E799758CEE75DAe3d84e09D40dc416eCf713652;

    IPendleRewardsClaimer internal _hookReceiver;
    ISiloConfig internal _siloConfig;
    ISiloIncentivesController internal _incentivesControllerCollateral;
    ISiloIncentivesController internal _incentivesControllerProtected;
    ISiloIncentivesControllerGaugeLikeFactory internal _factory;

    event ConfigUpdated(
        IPendleMarketLike _pendleMarket,
        ISiloIncentivesController _incentivesControllerCollateral,
        ISiloIncentivesController _incentivesControllerProtected
    );

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("RPC_MAINNET"), _BLOCK_TO_FORK);

        AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, _dao);

        _siloConfig = _setUpLocalFixtureNoOverrides(SiloConfigsNames.SILO_PENDLE_REWARDS_TEST);

        _hookReceiver = IPendleRewardsClaimer(address(IShareToken(address(silo0)).hookSetup().hookReceiver));

        _factory = ISiloIncentivesControllerGaugeLikeFactory(SiloCoreDeployments.get(
            SiloCoreContracts.INCENTIVES_CONTROLLER_GAUGE_LIKE_FACTORY,
            ChainsLib.chainAlias()
        ));

        _incentivesControllerCollateral = ISiloIncentivesController(_factory.createGaugeLike(
            _dao,
            address(_hookReceiver),
            address(silo0))
        );

        (address protected,,) = _siloConfig.getShareTokens(address(silo0));

        _incentivesControllerProtected = ISiloIncentivesController(_factory.createGaugeLike(
            _dao,
            address(_hookReceiver),
            address(protected))
        );

        IGaugeHookReceiver gaugeHookReceiver = IGaugeHookReceiver(address(_hookReceiver));

        vm.prank(_dao);
        gaugeHookReceiver.setGauge(
            IGauge(address(_incentivesControllerCollateral)),
            IShareToken(address(silo0))
        );

        vm.prank(_dao);
        gaugeHookReceiver.setGauge(
            IGauge(address(_incentivesControllerProtected)),
            IShareToken(address(protected))
        );
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi -vvv --mt testReInitialization
    function testReInitialization() public {
        address hookReceiverImpl = AddrLib.getAddress(SiloCoreContracts.PENDLE_REWARDS_CLAIMER);

        bytes memory data = abi.encode(address(this));

        // Pendle rewards claimer implementation is not initializable
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        IHookReceiver(hookReceiverImpl).initialize(ISiloConfig(address(0)), data);

        // Pendle rewards claimer can't be re-initialized
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _hookReceiver.initialize(ISiloConfig(address(0)), data);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_setConfig_onlyOwner -vv
    function test_setConfig_onlyOwner() public {
        vm.prank(_depositor);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _depositor));
        _hookReceiver.setConfig(
            IPendleMarketLike(address(0)),
            _incentivesControllerCollateral,
            _incentivesControllerProtected
        );
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_setConfig_WrongPendleMarket -vv
    function test_setConfig_WrongPendleMarket() public {
        vm.prank(_dao);
        vm.expectRevert(abi.encodeWithSelector(IPendleRewardsClaimer.WrongPendleMarket.selector));
        _hookReceiver.setConfig(
            IPendleMarketLike(address(0)),
            _incentivesControllerCollateral,
            _incentivesControllerProtected
        );
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_setConfig_EmptyAddress -vv
    function test_setConfig_EmptyAddress() public {
        address asset = address(silo0.asset());

        vm.prank(_dao);
        vm.expectRevert(abi.encodeWithSelector(IPendleRewardsClaimer.EmptyAddress.selector));
        _hookReceiver.setConfig(
            IPendleMarketLike(asset),
            ISiloIncentivesController(address(0)),
            _incentivesControllerProtected
        );

        vm.prank(_dao);
        vm.expectRevert(abi.encodeWithSelector(IPendleRewardsClaimer.EmptyAddress.selector));
        _hookReceiver.setConfig(
            IPendleMarketLike(asset),
            _incentivesControllerCollateral,
            ISiloIncentivesController(address(0))
        );
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_setConfig_reverts_invalidNotifier -vv
    function test_setConfig_reverts_invalidNotifier() public {
        address asset = address(silo0.asset());

        vm.prank(_dao);
        vm.expectRevert();
        _hookReceiver.setConfig(
            IPendleMarketLike(asset),
            ISiloIncentivesController(makeAddr("InvalidNotifier")),
            _incentivesControllerProtected
        );
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_setConfig_WrongNotifier -vv
    function test_setConfig_WrongNotifier() public {
        address asset = address(silo0.asset());
        (address protected,,) = _siloConfig.getShareTokens(address(silo0));

        ISiloIncentivesController controller = ISiloIncentivesController(_factory.createGaugeLike(
            _dao,
            address(this),
            address(protected)
        ));

        vm.prank(_dao);
        vm.expectRevert(
            abi.encodeWithSelector(IPendleRewardsClaimer.WrongCollateralIncentivesControllerNotifier.selector)
        );

        _hookReceiver.setConfig(
            IPendleMarketLike(asset),
            controller,
            _incentivesControllerProtected
        );

        vm.prank(_dao);
        vm.expectRevert(
            abi.encodeWithSelector(IPendleRewardsClaimer.WrongProtectedIncentivesControllerNotifier.selector)
        );

        _hookReceiver.setConfig(
            IPendleMarketLike(asset),
            _incentivesControllerCollateral,
            controller
        );
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_setConfig_WrongShareToken -vv
    function test_setConfig_WrongShareToken() public {
        address asset = address(silo0.asset());

        ISiloIncentivesController controller = ISiloIncentivesController(_factory.createGaugeLike(
            _dao,
            address(_hookReceiver),
            address(this)
        ));

        vm.prank(_dao);
        vm.expectRevert(
            abi.encodeWithSelector(IPendleRewardsClaimer.WrongCollateralIncentivesControllerShareToken.selector)
        );

        _hookReceiver.setConfig(
            IPendleMarketLike(asset),
            controller,
            _incentivesControllerProtected
        );

        vm.prank(_dao);
        vm.expectRevert(
            abi.encodeWithSelector(IPendleRewardsClaimer.WrongProtectedIncentivesControllerShareToken.selector)
        );

        _hookReceiver.setConfig(
            IPendleMarketLike(asset),
            _incentivesControllerCollateral,
            controller
        );
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_setConfig_success -vv
    function test_setConfig_success() public {
        address asset = silo0.asset();

        vm.expectEmit(true, true, true, true);
        emit ConfigUpdated(
            IPendleMarketLike(asset),
            _incentivesControllerCollateral,
            _incentivesControllerProtected
        );

        vm.prank(_dao);
        _hookReceiver.setConfig(
            IPendleMarketLike(asset),
            _incentivesControllerCollateral,
            _incentivesControllerProtected
        );
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_redeemRewardsFromPendle_onlyHookReceiver -vv
    function test_redeemRewardsFromPendle_onlyHookReceiver() public {
        vm.expectRevert(abi.encodeWithSelector(IPendleRewardsClaimer.OnlyHookReceiver.selector));
        PendleRewardsClaimer(address(_hookReceiver)).redeemRewardsFromPendle(
            IPendleMarketLike(address(0)),
            _incentivesControllerCollateral,
            _incentivesControllerProtected
        );
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_beforeAction_onlySilo -vv
    function test_beforeAction_onlySilo() public {
        vm.expectRevert(abi.encodeWithSelector(IHookReceiver.OnlySilo.selector));
        _hookReceiver.beforeAction(address(0), 0, "");
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_afterAction_onlySiloOrShareToken -vv
    function test_afterAction_onlySiloOrShareToken() public {
        vm.expectRevert(abi.encodeWithSelector(IHookReceiver.OnlySiloOrShareToken.selector));
        _hookReceiver.afterAction(address(0), 0, "");
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_redeemRewards_missingConfiguration -vv
    function test_redeemRewards_missingConfiguration() public {
        vm.expectRevert(abi.encodeWithSelector(IPendleRewardsClaimer.MissingConfiguration.selector));
        _hookReceiver.redeemRewards();
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_redeemRewardsSilo -vv
    function test_redeemRewardsSilo() public {
        IERC20 asset = IERC20(silo0.asset());

        vm.prank(_dao);
        _hookReceiver.setConfig(
            IPendleMarketLike(address(asset)),
            _incentivesControllerCollateral,
            _incentivesControllerProtected
        );

        uint256 amount = asset.balanceOf(_depositor);

        vm.prank(_depositor);
        asset.approve(address(silo0), amount);
        vm.prank(_depositor);
        silo0.deposit(amount, _depositor, ISilo.CollateralType.Collateral);

        vm.warp(block.timestamp + 2 days);
        vm.roll(vm.getBlockNumber() + 100);

        vm.prank(_depositor);
        silo0.withdraw(amount, _depositor, _depositor, ISilo.CollateralType.Collateral);

        string memory rewardTokenProgramName = "0x808507121b80c02388fad14726482e061b8da827";

        string[] memory programs = IDistributionManager(address(_incentivesControllerCollateral)).getAllProgramsNames();

        assertEq(programs.length, 1, "Expected 1 program");
        assertEq(programs[0], rewardTokenProgramName, "Expected reward token");

        uint256 rewardsBefore = IERC20(_rewardToken).balanceOf(_depositor);

        vm.warp(block.timestamp + 1 seconds);

        // user claim rewards from the silo incentives controller
        vm.prank(_depositor);
        _incentivesControllerCollateral.claimRewards(_depositor);

        uint256 rewardsAfter = IERC20(_rewardToken).balanceOf(_depositor);

        assertGt(rewardsAfter, rewardsBefore, "Depositor should have received rewards");
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_redeemRewards_withProtected -vv
    function test_redeemRewards_withProtected() public {
        IERC20 asset = IERC20(silo0.asset());

        vm.prank(_dao);
        _hookReceiver.setConfig(
            IPendleMarketLike(address(asset)),
            _incentivesControllerCollateral,
            _incentivesControllerProtected
        );

        uint256 collateralAmount = asset.balanceOf(_depositor);

        vm.prank(_depositor);
        asset.approve(address(silo0), collateralAmount);
        vm.prank(_depositor);
        silo0.deposit(collateralAmount, _depositor, ISilo.CollateralType.Collateral);

        uint256 protectedAmount = collateralAmount / 2;

        vm.prank(_lptWhale);
        asset.approve(address(silo0), protectedAmount);
        vm.prank(_lptWhale);
        silo0.deposit(protectedAmount, _lptWhale, ISilo.CollateralType.Protected);

        vm.warp(block.timestamp + 2 days);
        vm.roll(vm.getBlockNumber() + 100);

        uint256 collateralRewardsBefore = IERC20(_rewardToken).balanceOf(_depositor);
        uint256 protectedRewardsBefore = IERC20(_rewardToken).balanceOf(_lptWhale);

        _hookReceiver.redeemRewards();

        // users claim rewards from the silo incentives controller
        vm.prank(_depositor);
        _incentivesControllerCollateral.claimRewards(_depositor);
        vm.prank(_lptWhale);
        _incentivesControllerProtected.claimRewards(_lptWhale);

        uint256 collateralRewardsAfter = IERC20(_rewardToken).balanceOf(_depositor);
        uint256 protectedRewardsAfter = IERC20(_rewardToken).balanceOf(_lptWhale);

        assertGt(collateralRewardsAfter, collateralRewardsBefore, "Depositor should have received rewards");
        assertGt(protectedRewardsAfter, protectedRewardsBefore, "Lpt whale should have received rewards");

        uint256 collateralRewardsReceived = collateralRewardsAfter - collateralRewardsBefore;
        uint256 protectedRewardsReceived = protectedRewardsAfter - protectedRewardsBefore;

        assertEq(collateralRewardsReceived / 2, protectedRewardsReceived, "Rewards split proportionally");
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_redeemRewardsEverySecond -vv
    function test_redeemRewardsEverySecond() public {
        IERC20 asset = IERC20(silo0.asset());

        vm.prank(_dao);
        _hookReceiver.setConfig(
            IPendleMarketLike(address(asset)),
            _incentivesControllerCollateral,
            _incentivesControllerProtected
        );

        uint256 amount = asset.balanceOf(_depositor);

        vm.prank(_depositor);
        asset.approve(address(silo0), amount);
        vm.prank(_depositor);
        silo0.deposit(amount, _depositor, ISilo.CollateralType.Collateral);

        for (uint256 i = 0; i < 100; i++) {
            vm.warp(block.timestamp + 1 seconds);
            vm.roll(vm.getBlockNumber() + 1);

            uint256 rewardsBefore = IERC20(_rewardToken).balanceOf(_depositor);

            _hookReceiver.redeemRewards();

            // user claim rewards from the silo incentives controller
            vm.prank(_depositor);
            _incentivesControllerCollateral.claimRewards(_depositor);

            uint256 rewardsAfter = IERC20(_rewardToken).balanceOf(_depositor);

            assertGt(rewardsAfter, rewardsBefore, "Depositor should have received rewards");
        }
    }
}
