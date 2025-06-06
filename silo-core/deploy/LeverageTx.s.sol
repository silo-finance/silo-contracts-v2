// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {CommonDeploy} from "./_CommonDeploy.sol";

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {LeverageUsingSiloFlashloanWithGeneralSwap} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";

import {ISiloLens} from "silo-core/contracts/interfaces/ISiloLens.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ILeverageUsingSiloFlashloan} from "silo-core/contracts/interfaces/ILeverageUsingSiloFlashloan.sol";
import {IGeneralSwapModule} from "silo-core/contracts/interfaces/IGeneralSwapModule.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/LeverageTx.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast

 */
contract LeverageTx is CommonDeploy {
    ISiloConfig constant siloConfig = ISiloConfig(0x16b621A9219b2dDc64C50643d1e5ad3686806084);
    ISilo constant usdcSilo = ISilo(0x8C96c244586E0d8F6889413F7F525DaDE3b4Ab85);
    ISilo constant ptSilo = ISilo(0xfb6587720C73Bc086e2978983538AD3011123161);

    function run() public returns (LeverageUsingSiloFlashloanWithGeneralSwap leverage) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        leverage = LeverageUsingSiloFlashloanWithGeneralSwap(0x835E3bB0DA8b7D304df2fE29fBAf751a0e3D4024);
        uint256 depositAmount = 0.01e6;

        IERC20 ptAsset = IERC20(ptSilo.asset());
        IERC20 usdcAsset = IERC20(usdcSilo.asset());

        (,, address debtShareToken) = siloConfig.getShareTokens(address(usdcSilo));

        // flashloan USDC

        ILeverageUsingSiloFlashloan.FlashArgs memory flashArgs = ILeverageUsingSiloFlashloan.FlashArgs({
            amount: 0.02e6,
            flashloanTarget: address(usdcSilo)
        });

        // swap USDC -> PT

        /* this data should be provided by BE API
         NOTICE: user needs to give allowance for swap router to use tokens

        Pendle SWAP API
        https://api-v2.pendle.finance/core/docs#/SDK/SdkController_swap
        - receiver: must be leverage contract


        market:
        https://app.pendle.finance/trade/markets?utm_source=landing&utm_medium=landing&chains=sonic&search=AAVE

        API CALL for Pendle SWAP
        https://api-v2.pendle.finance/core/v1/sdk/146/markets/0x3f5ea53d1160177445b1898afbb16da111182418/swap?receiver=0x835E3bB0DA8b7D304df2fE29fBAf751a0e3D4024&slippage=0.01&enableAggregator=true&tokenIn=0x29219dd400f2Bf60E5a23d13Be72B486D4038894&tokenOut=0x930441Aa7Ab17654dF5663781CA0C02CC17e6643&amountIn=200000

        */

        IGeneralSwapModule.SwapArgs memory swapArgs = IGeneralSwapModule.SwapArgs({
            sellToken: address(usdcAsset), //
            buyToken: address(ptAsset),
            // API output field: $.tx.to
            allowanceTarget: address(0x888888888889758F76e7103c6CbF23ABbF58F946),
            // API output field: $.tx.to
            exchangeProxy: address(0x888888888889758F76e7103c6CbF23ABbF58F946),
            // API output field: $.tx.data
            swapCallData: hex"c81f847a000000000000000000000000835e3bb0da8b7d304df2fe29fbaf751a0e3d40240000000000000000000000003f5ea53d1160177445b1898afbb16da1111824180000000000000000000000000000000000000000000000000000000000004e53000000000000000000000000000000000000000000000000000000000000278f00000000000000000000000000000000000000000000000000000000000053120000000000000000000000000000000000000000000000000000000000004f1e000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000011c37937e080000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000028000000000000000000000000029219dd400f2bf60e5a23d13be72b486d40388940000000000000000000000000000000000000000000000000000000000004e2000000000000000000000000029219dd400f2bf60e5a23d13be72b486d4038894000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        });

        // deposit PT
        ILeverageUsingSiloFlashloan.DepositArgs memory depositArgs = ILeverageUsingSiloFlashloan.DepositArgs({
            amount: depositAmount,
            collateralType: ISilo.CollateralType.Collateral,
            silo: ptSilo
        });

        // repay flashloan will be done by borrow USDC


        uint256 debtReceiveApproval = _calculateDebtReceiveApproval(
            flashArgs.amount, ISilo(flashArgs.flashloanTarget)
        );

        _displayBorrowerState();

        vm.startBroadcast(deployerPrivateKey);

        // approvals

        // siloLeverage needs approval to pull user tokens to do deposit in behalf of user
        ptAsset.approve(address(leverage), depositArgs.amount);

        // user must set approvals for debt share token
        // IERC20(debtShareToken).approve(address(leverage), debtReceiveApproval);
        IERC20R(debtShareToken).setReceiveApproval(address(leverage), debtReceiveApproval);
        // receiveAllowance will be needed for newest Silos

        // OPEN

        leverage.openLeveragePosition(flashArgs, abi.encode(swapArgs), depositArgs);

        vm.stopBroadcast();

        _displayBorrowerState();
    }

    function _calculateDebtReceiveApproval(
        uint256 _flashAmount,
        ISilo _flashFrom
    ) internal view returns (uint256 debtReceiveApproval) {
        uint256 borrowAssets = _flashAmount + _flashFrom.flashFee(_flashFrom.asset(), _flashAmount);
        debtReceiveApproval = _flashFrom.convertToShares(borrowAssets, ISilo.AssetType.Debt);
    }

    function _displayBorrowerState() internal view {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address borrower = vm.addr(deployerPrivateKey);
        IERC20 ptAsset = IERC20(ptSilo.asset());
        IERC20 usdcAsset = IERC20(usdcSilo.asset());

        console2.log("____________");

        uint256 shares = ptSilo.balanceOf(borrower);

        console2.log("PT balance", ptAsset.balanceOf(borrower));
        console2.log("USDC balance", usdcAsset.balanceOf(borrower));

        console2.log("COLLATERAL", ptSilo.previewRedeem(shares));
        console2.log("MAX DEBT", usdcSilo.maxRepay(borrower));
    }
}
