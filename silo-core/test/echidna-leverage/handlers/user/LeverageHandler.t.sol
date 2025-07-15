// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ILeverageUsingSiloFlashloan} from "silo-core/contracts/interfaces/ILeverageUsingSiloFlashloan.sol";
import {IERC3156FlashLender} from "silo-core/contracts/interfaces/IERC3156FlashLender.sol";
import {IGeneralSwapModule} from "silo-core/contracts/interfaces/IGeneralSwapModule.sol";
import {LeverageUsingSiloFlashloanWithGeneralSwap, LeverageUsingSiloFlashloan} from
    "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {LeverageRouterRevenueModule} from "silo-core/contracts/leverage/modules/LeverageRouterRevenueModule.sol";
import {RevenueModule} from "silo-core/contracts/leverage/modules/RevenueModule.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Actor} from "silo-core/test/invariants/utils/Actor.sol";

// Libraries
import {console2} from "forge-std/console2.sol";

// Test Contracts
import {BaseHandlerLeverage} from "../../base/BaseHandlerLeverage.t.sol";
import {TestERC20} from "silo-core/test/invariants/utils/mocks/TestERC20.sol";
import {TestWETH} from "silo-core/test/echidna-leverage/utils/mocks/TestWETH.sol";

/// @title LeverageHandler
/// @notice Handler test contract for a set of actions
contract LeverageHandler is BaseHandlerLeverage {
    function rescueTokens(IERC20 _token, uint256 _i) external payable setupRandomActor(_i) {
        RevenueModule revenueModule = RevenueModule(leverageRouter.predictUserLeverageContract(targetActor));

        _before();

        (bool success,) = actor.proxy{value: msg.value}(
            address(revenueModule), abi.encodeWithSelector(RevenueModule.rescueTokens.selector, _token)
        );

        if (success) {
            _after();
        }

        assertEq(
            _token.balanceOf(address(revenueModule)), 0, "after rescue (success of fail) there should be 0 tokens"
        );

        assert_AllowanceDoesNotChangedForUserWhoOnlyApprove();
    }

    function swapModuleDonation(uint256 _t) external {
        _donation(address(_swapModuleAddress()), _t);
    }

    function siloLeverageImplementationDonation(uint256 _t) external {
        _donation(leverageRouter.LEVERAGE_IMPLEMENTATION(), _t);
    }

    function revenueModelDonation(uint256 _t, uint256 _i) external {
        _donation(address(_userLeverageContract(targetActor)), _t);
    }

    function siloLeverageDonation(uint256 _t) external {
        _donation(address(leverageRouter), _t);
    }

    function setLeverageFee(uint256 _fee) external {
        address owner = leverageRouter.owner();

        _before();

        vm.prank(owner);
        try leverageRouter.setLeverageFee(_fee) {
            _after();
        } catch {
        }
    }

    function onFlashLoan(
        address _initiator,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data,
        RandomGenerator calldata _random
    )
        external
        payable
        setupRandomActor(_random.i)
    {
        address silo = _getRandomSilo(_random.j);

        _before();

        address _borrowToken = ISilo(silo).asset();

        (bool success,) = actor.proxy{value: msg.value}(
            address(_userLeverageContract(targetActor)),
            abi.encodeWithSelector(
                LeverageUsingSiloFlashloan.onFlashLoan.selector,
                _initiator,
                _borrowToken,
                _flashloanAmount,
                _flashloanFee,
                _data
            )
        );

        if (success) {
            _after();

            assertTrue(
                false,
                "[onFlashLoan] direct call on onFlashLoan should always revert"
            );
        }

        assert_AllowanceDoesNotChangedForUserWhoOnlyApprove();
    }

    function openLeveragePosition(uint64 _depositPercent, uint64 _flashloanPercent, RandomGenerator calldata _random)
        external
        payable
        setupRandomActor(_random.i)
    {
        uint256 _PRECISION = 1e18;

        // it allows to set 110%, so we do not exclude cases when user pick value that is too high
        _flashloanPercent = _flashloanPercent % 1.1e18;
        _depositPercent = _depositPercent % 1.1e18;

        console2.log("targetActor", targetActor, address(actor));

        if (_userWhoOnlyApprove() == targetActor) {
            assert_AllowanceDoesNotChangedForUserWhoOnlyApprove();
            return;
        }

        address silo = _getRandomSilo(_random.j);

        ILeverageUsingSiloFlashloan.FlashArgs memory flashArgs;
        ILeverageUsingSiloFlashloan.DepositArgs memory depositArgs;
        IGeneralSwapModule.SwapArgs memory swapArgs;

        address otherSilo = _getOtherSilo(silo);
        uint256 maxFlashloan = IERC3156FlashLender(otherSilo).maxFlashLoan(ISilo(otherSilo).asset());

        flashArgs = ILeverageUsingSiloFlashloan.FlashArgs({
            amount: maxFlashloan * _flashloanPercent / _PRECISION,
            flashloanTarget: otherSilo
        });

        address depositAsset = ISilo(silo).asset();

        depositArgs = ILeverageUsingSiloFlashloan.DepositArgs({
            amount: IERC20(depositAsset).balanceOf(targetActor) * _depositPercent / _PRECISION,
            collateralType: ISilo.CollateralType(_random.k % 2),
            silo: ISilo(silo)
        });

        swapArgs = IGeneralSwapModule.SwapArgs({
            buyToken: depositArgs.silo.asset(),
            sellToken: ISilo(flashArgs.flashloanTarget).asset(),
            allowanceTarget: address(swapRouterMock),
            exchangeProxy: address(swapRouterMock),
            swapCallData: "mocked swap data"
        });

        // swap with 0.5% slippage
        swapRouterMock.setSwap(swapArgs.sellToken, flashArgs.amount, swapArgs.buyToken, flashArgs.amount * 995 / 1000);

        _before();

        uint256 beforeDebt = ISilo(flashArgs.flashloanTarget).maxRepay(targetActor);

        (bool success,) = actor.proxy{value: msg.value}(
            address(leverageRouter),
            abi.encodeWithSelector(
                ILeverageUsingSiloFlashloan.openLeveragePosition.selector, flashArgs, abi.encode(swapArgs), depositArgs
            )
        );

        uint256 afterDebt = ISilo(flashArgs.flashloanTarget).maxRepay(targetActor);

        if (success) {
            _after();

            assertEq(
                ISilo(flashArgs.flashloanTarget).maxRepay(targetActor),
                beforeDebt + flashArgs.amount + depositArgs.amount,
                "[openLeveragePosition] borrower should have debt created by leverage"
            );
        } else {
            assertEq(beforeDebt, afterDebt, "[openLeveragePosition] when leverage fail, debt does not change");
        }

        assert_AllowanceDoesNotChangedForUserWhoOnlyApprove();
    }

    function closeLeveragePosition(RandomGenerator calldata _random) external setupRandomActor(_random.i) {
        if (_userWhoOnlyApprove() == targetActor) {
            assert_AllowanceDoesNotChangedForUserWhoOnlyApprove();
            return;
        }

        address silo = _getRandomSilo(_random.j);

        ILeverageUsingSiloFlashloan.CloseLeverageArgs memory closeArgs;
        IGeneralSwapModule.SwapArgs memory swapArgs;

        closeArgs = ILeverageUsingSiloFlashloan.CloseLeverageArgs({
            flashloanTarget: _getOtherSilo(silo),
            siloWithCollateral: ISilo(silo),
            collateralType: ISilo.CollateralType(_random.k % 2)
        });

        uint256 flashAmount = ISilo(closeArgs.flashloanTarget).maxRepay(targetActor);
        uint256 amountIn = flashAmount * 111 / 100;
        // swap with 0.5% slippage
        swapRouterMock.setSwap(swapArgs.sellToken, amountIn, swapArgs.buyToken, amountIn * 995 / 1000);

        swapArgs = IGeneralSwapModule.SwapArgs({
            buyToken: ISilo(closeArgs.flashloanTarget).asset(),
            sellToken: ISilo(closeArgs.siloWithCollateral).asset(),
            allowanceTarget: address(swapRouterMock),
            exchangeProxy: address(swapRouterMock),
            swapCallData: "mocked swap data"
        });

        _before();

        (bool success,) = actor.proxy(
            address(leverageRouter),
            abi.encodeWithSelector(
                ILeverageUsingSiloFlashloan.closeLeveragePosition.selector, abi.encode(swapArgs), closeArgs
            )
        );

        if (success) {
            _after();
            assertEq(ISilo(closeArgs.flashloanTarget).maxRepay(targetActor), 0, "borrower should have no debt");
        }
    }

    function assert_AllowanceDoesNotChangedForUserWhoOnlyApprove() public {
        assertEq(
            _asset0.allowance(_userWhoOnlyApprove(), address(leverageRouter)), type(uint256).max, "approval0 must stay"
        );
        assertEq(
            _asset1.allowance(_userWhoOnlyApprove(), address(leverageRouter)), type(uint256).max, "approval1 must stay"
        );
    }

    function echidna_AllowanceDoesNotChangedForUserWhoOnlyApprove() public returns (bool) {
        assert_AllowanceDoesNotChangedForUserWhoOnlyApprove();

        return true;
    }

    function _userWhoOnlyApprove() internal view returns (address) {
        // this user only approve leverage and we expect approval did not changed
        return actorAddresses[0];
    }

    function _donation(address _target, uint256 _t) internal {
        if (_t == 0) {
            payable(_target).transfer(1e18);

            assertGt(_target.balance, 0, "[_donation] expect ETH to be send");
        } else {
            TestERC20 token = _t % 2 == 0 ? _asset0 : _asset1;
            token.mint(_target, 1e18);

            assertGt(token.balanceOf(_target), 0, "[_donation] expect tokens to be send");
        }
    }

    function _userLeverageContract(address _user) internal returns (LeverageUsingSiloFlashloanWithGeneralSwap) {
        return LeverageUsingSiloFlashloanWithGeneralSwap(leverageRouter.predictUserLeverageContract(_user));
    }

    function _swapModuleAddress() internal returns (IGeneralSwapModule swapModule) {
        return LeverageUsingSiloFlashloanWithGeneralSwap(leverageRouter.LEVERAGE_IMPLEMENTATION()).SWAP_MODULE();
    }
}
