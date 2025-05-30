// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";
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
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IDistributionManager} from "silo-core/contracts/incentives/interfaces/IDistributionManager.sol";
import {PendleMarketThatReverts} from "../../../_mocks/PendleMarketThatReverts.sol";
import {SiloLittleHelper} from  "../../../_common/SiloLittleHelper.sol";
import {TransferOwnership} from  "../../../_common/TransferOwnership.sol";
import {
    ISiloIncentivesControllerGaugeLikeFactory
} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol";

// FOUNDRY_PROFILE=core_test forge test --ffi --mc PendleRewardsClaimerTest -vv
contract PendleRewardsClaimerTest is SiloLittleHelper, Test, TransferOwnership {
    uint256 internal constant _BLOCK_TO_FORK = 22518257;

    address internal _dao = makeAddr("DAO");
    address internal _depositor = 0xf06e212f3d021842f1C8c2De4b9dd04945717aDd;
    address internal _rewardToken = 0x808507121B80c02388fAd14726482e061B8da827;
    address internal _lptWhale = 0x6E799758CEE75DAe3d84e09D40dc416eCf713652;

    IPendleRewardsClaimer internal _hookReceiver;
    ISiloConfig internal _siloConfig;
    ISiloIncentivesController internal _incentivesController;
    ISiloIncentivesControllerGaugeLikeFactory internal _factory;

    event FailedToClaimIncentives(address _silo);

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("RPC_MAINNET"), _BLOCK_TO_FORK);

        AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, _dao);

        _siloConfig = _setUpLocalFixtureNoOverrides(SiloConfigsNames.SILO_PENDLE_REWARDS_TEST);

        _hookReceiver = IPendleRewardsClaimer(address(IShareToken(address(silo0)).hookSetup().hookReceiver));

        _factory = ISiloIncentivesControllerGaugeLikeFactory(SiloCoreDeployments.get(
            SiloCoreContracts.INCENTIVES_CONTROLLER_GAUGE_LIKE_FACTORY,
            ChainsLib.chainAlias()
        ));

        (address protected,,) = _siloConfig.getShareTokens(address(silo0));

        _incentivesController = ISiloIncentivesController(_factory.createGaugeLike(
            _dao,
            address(_hookReceiver),
            address(protected))
        );

        IGaugeHookReceiver gaugeHookReceiver = IGaugeHookReceiver(address(_hookReceiver));

        vm.prank(_dao);
        gaugeHookReceiver.setGauge(
            IGauge(address(_incentivesController)),
            IShareToken(address(protected))
        );
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi -vvv --mt test_reInitialization
    function test_reInitialization() public {
        address hookReceiverImpl = AddrLib.getAddress(SiloCoreContracts.PENDLE_REWARDS_CLAIMER);

        bytes memory data = abi.encode(address(this));

        // Pendle rewards claimer implementation is not initializable
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        IHookReceiver(hookReceiverImpl).initialize(ISiloConfig(address(0)), data);

        // Pendle rewards claimer can't be re-initialized
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _hookReceiver.initialize(ISiloConfig(address(0)), data);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_collateralDeposits_notPossible -vv
    function test_collateralDeposits_notPossible() public {
        IERC20 asset = IERC20(silo0.asset());
        uint256 amount = asset.balanceOf(_depositor);

        vm.prank(_depositor);
        asset.approve(address(silo0), amount);
        vm.prank(_depositor);
        vm.expectRevert(abi.encodeWithSelector(IPendleRewardsClaimer.CollateralDepositNotAllowed.selector));
        silo0.deposit(amount, _depositor, ISilo.CollateralType.Collateral);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_redeemRewardsFromPendle_and_claim -vv
    function test_redeemRewardsFromPendle_and_claim() public {
        IERC20 asset = IERC20(silo0.asset());
        uint256 amount = asset.balanceOf(_depositor);

        _depositProtected();

        vm.warp(block.timestamp + 2 days);
        vm.roll(vm.getBlockNumber() + 100);

        vm.prank(_depositor);
        silo0.withdraw(amount, _depositor, _depositor, ISilo.CollateralType.Protected);

        string memory rewardTokenProgramName = "0x808507121b80c02388fad14726482e061b8da827";

        string[] memory programs = IDistributionManager(address(_incentivesController)).getAllProgramsNames();

        assertEq(programs.length, 1, "Expected 1 program");
        assertEq(programs[0], rewardTokenProgramName, "Expected reward token");

        uint256 rewardsBefore = IERC20(_rewardToken).balanceOf(_depositor);

        vm.warp(block.timestamp + 1 seconds);

        // user claim rewards from the silo incentives controller
        vm.prank(_depositor);
        _incentivesController.claimRewards(_depositor);

        uint256 rewardsAfter = IERC20(_rewardToken).balanceOf(_depositor);

        assertGt(rewardsAfter, rewardsBefore, "Depositor should have received rewards");
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_redeemRewardsEverySecond -vv
    function test_redeemRewardsEverySecond() public {
        _depositProtected();

        for (uint256 i = 0; i < 100; i++) {
            vm.warp(block.timestamp + 1 seconds);
            vm.roll(vm.getBlockNumber() + 1);

            uint256 rewardsBefore = IERC20(_rewardToken).balanceOf(_depositor);

            _hookReceiver.redeemRewards();

            // user claim rewards from the silo incentives controller
            vm.prank(_depositor);
            _incentivesController.claimRewards(_depositor);

            uint256 rewardsAfter = IERC20(_rewardToken).balanceOf(_depositor);

            assertGt(rewardsAfter, rewardsBefore, "Depositor should have received rewards");
        }
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_transferShouldClaimRewards -vv
    function test_transferShouldClaimRewards() public {
        _depositProtected();

        vm.warp(block.timestamp + 1 seconds);
        vm.roll(vm.getBlockNumber() + 1);

        (address protected,,) = _siloConfig.getShareTokens(address(silo0));

        uint256 rewardsBefore = IERC20(_rewardToken).balanceOf(_depositor);

        uint256 amount = IERC20(protected).balanceOf(_depositor);
        assertNotEq(amount, 0, "Depositor should have some protected tokens");

        vm.prank(_depositor);
        IERC20(protected).transfer(address(this), amount);

        vm.prank(_depositor);
        _incentivesController.claimRewards(_depositor);

        uint256 rewardsAfter = IERC20(_rewardToken).balanceOf(_depositor);

        assertGt(rewardsAfter, rewardsBefore, "Depositor should have received rewards");
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_redeemRewards_reverts -vv
    function test_redeemRewards_reverts() public {
        _depositProtected();

        IERC20 asset = IERC20(silo0.asset());

        (address protected,,) = _siloConfig.getShareTokens(address(silo0));

        uint256 amount = IERC20(protected).balanceOf(_depositor);
        assertNotEq(amount, 0, "Depositor should have deposit");

        PendleMarketThatReverts pendleMarket = new PendleMarketThatReverts();
        vm.etch(address(asset), address(pendleMarket).code);

        uint256 maxWithdrawAmount = silo0.maxWithdraw(_depositor, ISilo.CollateralType.Protected);

        vm.expectEmit(true, true, true, true);
        emit FailedToClaimIncentives(address(silo0));

        vm.prank(_depositor);
        silo0.withdraw(maxWithdrawAmount, _depositor, _depositor, ISilo.CollateralType.Protected);

        amount = IERC20(protected).balanceOf(_depositor);
        assertEq(amount, 0, "Depositor should be able to withdraw when redeeming reverts");
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_redeemRewards_above104max -vv
    function test_redeemRewards_above104max() public {
        _depositProtected();

        IERC20 asset = IERC20(silo0.asset());

        (address protected,,) = _siloConfig.getShareTokens(address(silo0));

        uint256 amount = IERC20(protected).balanceOf(_depositor);
        assertNotEq(amount, 0, "Depositor should have deposit");

        ERC20Mock token = new ERC20Mock();

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(token);

        uint256 someAmount = uint256(type(uint104).max) * 10 + 3;

        token.mint(address(silo0), someAmount);

        assertEq(token.balanceOf(address(silo0)), someAmount, "Token should have rewards");
        assertEq(token.balanceOf(_depositor), 0, "Depositor should have no rewards");

        vm.mockCall(
            address(asset),
            abi.encodeWithSelector(IPendleMarketLike.getRewardTokens.selector),
            abi.encode(rewardTokens)
        );

        uint256[] memory rewards = new uint256[](1);
        rewards[0] = someAmount;

        vm.mockCall(
            address(asset),
            abi.encodeWithSelector(IPendleMarketLike.redeemRewards.selector, address(silo0)),
            abi.encode(rewards)
        );

        _hookReceiver.redeemRewards();

        assertEq(token.balanceOf(address(silo0)), 0, "Token should have no rewards");

        assertEq(
            token.balanceOf(address(_incentivesController)),
            someAmount,
            "Incentives controller should have rewards"
        );

        vm.prank(_depositor);
        _incentivesController.claimRewards(_depositor);

        // -1wei because of the rounding error in the Silo incentives controller
        assertEq(token.balanceOf(_depositor), type(uint104).max - 1, "Depositor should have receive type(uint104).max");
        // 1wei because of the rounding error in the Silo incentives controller
        assertEq(
            token.balanceOf(address(_incentivesController)),
            someAmount - type(uint104).max + 1,
            "Incentives controller should have have rewards above type(uint104).max"
        );
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_hookConfigurationDuringInit -vv
    function test_hookConfigurationDuringInit() public {
        (uint24 hooksBefore, uint24 hooksAfter) = _hookReceiver.hookReceiverConfig(address(silo0));
        
        // All before actions should be configured (type(uint24).max)
        assertEq(hooksBefore, type(uint24).max, "All before actions should be configured");

        // After actions should include protected token transfers
        uint256 protectedTransferAction = Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN);
        assertTrue(Hook.matchAction(protectedTransferAction, hooksAfter), "After actions should be configured");
    }

    function _depositProtected() internal {
        IERC20 asset = IERC20(silo0.asset());
        uint256 amount = asset.balanceOf(_depositor);

        vm.prank(_depositor);
        asset.approve(address(silo0), amount);
        vm.prank(_depositor);
        silo0.deposit(amount, _depositor, ISilo.CollateralType.Protected);
    }
}
