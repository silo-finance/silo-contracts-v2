// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IMethodReentrancyTest} from "./interfaces/IMethodReentrancyTest.sol";
import {AccrueInterestReentrancyTest} from "./silo-methods/AccrueInterestReentrancyTest.sol";
import {AccrueInterestForConfigReentrancyTest} from "./silo-methods/AccrueInterestForConfigReentrancyTest.sol";
import {AllowanceReentrancyTest} from "./silo-methods/AllowanceReentrancyTest.sol";
import {ApproveReentrancyTest} from "./silo-methods/ApproveReentrancyTest.sol";
import {AssetReentrancyTest} from "./silo-methods/AssetReentrancyTest.sol";
import {BalanceOfReentrancyTest} from "./silo-methods/BalanceOfReentrancyTest.sol";
import {BorrowReentrancyTest} from "./silo-methods/BorrowReentrancyTest.sol";
import {BorrowSharesReentrancyTest} from "./silo-methods/BorrowSharesReentrancyTest.sol";
import {CallOnBehalfOfSiloReentrancyTest} from "./silo-methods/CallOnBehalfOfSiloReentrancyTest.sol";
import {ConfigReentrancyTest} from "./silo-methods/ConfigReentrancyTest.sol";
import {ConvertToAssetsReentrancyTest} from "./silo-methods/ConvertToAssetsReentrancyTest.sol";
import {ConvertToAssetsWithTypeReentrancyTest} from "./silo-methods/ConvertToAssetsWithTypeReentrancyTest.sol";
import {ConvertToSharesReentrancyTest} from "./silo-methods/ConvertToSharesReentrancyTest.sol";
import {ConvertToSharesWithTypeReentrancyTest} from "./silo-methods/ConvertToSharesWithTypeReentrancyTest.sol";
import {DecimalsReentrancyTest} from "./silo-methods/DecimalsReentrancyTest.sol";
import {DepositReentrancyTest} from "./silo-methods/DepositReentrancyTest.sol";
import {DepositWithTypeReentrancyTest} from "./silo-methods/DepositWithTypeReentrancyTest.sol";
import {FactoryReentrancyTest} from "./silo-methods/FactoryReentrancyTest.sol";
import {FlashFeeReentrancyTest} from "./silo-methods/FlashFeeReentrancyTest.sol";
import {FlashLoanReentrancyTest} from "./silo-methods/FlashLoanReentrancyTest.sol";
import {GetCollateralAndDebtAssetsReentrancyTest} from "./silo-methods/GetCollateralAndDebtAssetsReentrancyTest.sol";
import {GetCollateralAndProtectedAssetsReentrancyTest}
    from "./silo-methods/GetCollateralAndProtectedAssetsReentrancyTest.sol";
import {GetCollateralAssetsReentrancyTest} from "./silo-methods/GetCollateralAssetsReentrancyTest.sol";
import {GetDebtAssetsReentrancyTest} from "./silo-methods/GetDebtAssetsReentrancyTest.sol";
import {GetLiquidityReentrancyTest} from "./silo-methods/GetLiquidityReentrancyTest.sol";
import {InitializeReentrancyTest} from "./silo-methods/InitializeReentrancyTest.sol";
import {IsSolventReentrancyTest} from "./silo-methods/IsSolventReentrancyTest.sol";
import {MaxBorrowReentrancyTest} from "./silo-methods/MaxBorrowReentrancyTest.sol";
import {MaxBorrowSharesReentrancyTest} from "./silo-methods/MaxBorrowSharesReentrancyTest.sol";
import {MaxDepositReentrancyTest} from "./silo-methods/MaxDepositReentrancyTest.sol";
import {MaxDepositWithTypeReentrancyTest} from "./silo-methods/MaxDepositWithTypeReentrancyTest.sol";
import {MaxFlashLoanReentrancyTest} from "./silo-methods/MaxFlashLoanReentrancyTest.sol";
import {MaxMintReentrancyTest} from "./silo-methods/MaxMintReentrancyTest.sol";
import {MaxMintWithTypeReentrancyTest} from "./silo-methods/MaxMintWithTypeReentrancyTest.sol";
import {MaxRedeemReentrancyTest} from "./silo-methods/MaxRedeemReentrancyTest.sol";
import {MaxRedeemWithTypeReentrancyTest} from "./silo-methods/MaxRedeemWithTypeReentrancyTest.sol";
import {MaxRepayReentrancyTest} from "./silo-methods/MaxRepayReentrancyTest.sol";
import {MaxRepaySharesReentrancyTest} from "./silo-methods/MaxRepaySharesReentrancyTest.sol";
import {MaxWithdrawReentrancyTest} from "./silo-methods/MaxWithdrawReentrancyTest.sol";
import {MaxWithdrawWithTypeReentrancyTest} from "./silo-methods/MaxWithdrawWithTypeReentrancyTest.sol";
import {MintReentrancyTest} from "./silo-methods/MintReentrancyTest.sol";
import {MintWithTypeReentrancyTest} from "./silo-methods/MintWithTypeReentrancyTest.sol";
import {NameReentrancyTest} from "./silo-methods/NameReentrancyTest.sol";
import {PreviewBorrowReentrancyTest} from "./silo-methods/PreviewBorrowReentrancyTest.sol";
import {PreviewBorrowSharesReentrancyTest} from "./silo-methods/PreviewBorrowSharesReentrancyTest.sol";
import {PreviewDepositReentrancyTest} from "./silo-methods/PreviewDepositReentrancyTest.sol";
import {PreviewDepositWithTypeReentrancyTest} from "./silo-methods/PreviewDepositWithTypeReentrancyTest.sol";
import {PreviewMintReentrancyTest} from "./silo-methods/PreviewMintReentrancyTest.sol";
import {PreviewMintWithTypeReentrancyTest} from "./silo-methods/PreviewMintWithTypeReentrancyTest.sol";
import {PreviewRedeemReentrancyTest} from "./silo-methods/PreviewRedeemReentrancyTest.sol";
import {PreviewRedeemWithTypeReentrancyTest} from "./silo-methods/PreviewRedeemWithTypeReentrancyTest.sol";
import {PreviewRepayReentrancyTest} from "./silo-methods/PreviewRepayReentrancyTest.sol";
import {PreviewRepaySharesReentrancyTest} from "./silo-methods/PreviewRepaySharesReentrancyTest.sol";
import {PreviewWithdrawReentrancyTest} from "./silo-methods/PreviewWithdrawReentrancyTest.sol";
import {PreviewWithdrawWithTypeReentrancyTest} from "./silo-methods/PreviewWithdrawWithTypeReentrancyTest.sol";
import {RedeemReentrancyTest} from "./silo-methods/RedeemReentrancyTest.sol";
import {RedeemWithTypeReentrancyTest} from "./silo-methods/RedeemWithTypeReentrancyTest.sol";
import {RepayReentrancyTest} from "./silo-methods/RepayReentrancyTest.sol";
import {RepaySharesReentrancyTest} from "./silo-methods/RepaySharesReentrancyTest.sol";
import {SharedStorageReentrancyTest} from "./silo-methods/SharedStorageReentrancyTest.sol";
import {SiloDataStorageReentrancyTest} from "./silo-methods/SiloDataStorageReentrancyTest.sol";
import {SwitchCollateralToReentrancyTest} from "./silo-methods/SwitchCollateralToReentrancyTest.sol";
import {SymbolReentrancyTest} from "./silo-methods/SymbolReentrancyTest.sol";
import {TotalReentrancyTest} from "./silo-methods/TotalReentrancyTest.sol";
import {TotalAssetsReentrancyTest} from "./silo-methods/TotalAssetsReentrancyTest.sol";
import {TotalSupplyReentrancyTest} from "./silo-methods/TotalSupplyReentrancyTest.sol";
import {WithdrawReentrancyTest} from "./silo-methods/WithdrawReentrancyTest.sol";
import {WithdrawWithTypeReentrancyTest} from "./silo-methods/WithdrawWithTypeReentrancyTest.sol";

contract MethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new AccrueInterestReentrancyTest());
        _registerMethod(new AccrueInterestForConfigReentrancyTest());
        _registerMethod(new AllowanceReentrancyTest());
        _registerMethod(new ApproveReentrancyTest());
        _registerMethod(new AssetReentrancyTest());
        _registerMethod(new BalanceOfReentrancyTest());
        _registerMethod(new BorrowReentrancyTest());
        _registerMethod(new BorrowSharesReentrancyTest());
        _registerMethod(new CallOnBehalfOfSiloReentrancyTest());
        _registerMethod(new ConfigReentrancyTest());
        _registerMethod(new ConvertToAssetsReentrancyTest());
        _registerMethod(new ConvertToAssetsWithTypeReentrancyTest());
        _registerMethod(new ConvertToSharesReentrancyTest());
        _registerMethod(new ConvertToSharesWithTypeReentrancyTest());
        _registerMethod(new DecimalsReentrancyTest());
        _registerMethod(new DepositReentrancyTest());
        _registerMethod(new DepositWithTypeReentrancyTest());
        _registerMethod(new FactoryReentrancyTest());
        _registerMethod(new FlashFeeReentrancyTest());
        _registerMethod(new FlashLoanReentrancyTest());
        _registerMethod(new GetCollateralAndDebtAssetsReentrancyTest());
        _registerMethod(new GetCollateralAndProtectedAssetsReentrancyTest());
        _registerMethod(new GetCollateralAssetsReentrancyTest());
        _registerMethod(new GetDebtAssetsReentrancyTest());
        _registerMethod(new GetLiquidityReentrancyTest());
        _registerMethod(new InitializeReentrancyTest());
        _registerMethod(new IsSolventReentrancyTest());
        _registerMethod(new MaxBorrowReentrancyTest());
        _registerMethod(new MaxBorrowSharesReentrancyTest());
        _registerMethod(new MaxDepositReentrancyTest());
        _registerMethod(new MaxDepositWithTypeReentrancyTest());
        _registerMethod(new MaxFlashLoanReentrancyTest());
        _registerMethod(new MaxMintReentrancyTest());
        _registerMethod(new MaxMintWithTypeReentrancyTest());
        _registerMethod(new MaxRedeemReentrancyTest());
        _registerMethod(new MaxRedeemWithTypeReentrancyTest());
        _registerMethod(new MaxRepayReentrancyTest());
        _registerMethod(new MaxRepaySharesReentrancyTest());
        _registerMethod(new MaxWithdrawReentrancyTest());
        _registerMethod(new MaxWithdrawWithTypeReentrancyTest());
        _registerMethod(new MintReentrancyTest());
        _registerMethod(new MintWithTypeReentrancyTest());
        _registerMethod(new NameReentrancyTest());
        _registerMethod(new PreviewBorrowReentrancyTest());
        _registerMethod(new PreviewBorrowSharesReentrancyTest());
        _registerMethod(new PreviewDepositReentrancyTest());
        _registerMethod(new PreviewDepositWithTypeReentrancyTest());
        _registerMethod(new PreviewMintReentrancyTest());
        _registerMethod(new PreviewMintWithTypeReentrancyTest());
        _registerMethod(new PreviewRedeemReentrancyTest());
        _registerMethod(new PreviewRedeemWithTypeReentrancyTest());
        _registerMethod(new PreviewRepayReentrancyTest());
        _registerMethod(new PreviewRepaySharesReentrancyTest());
        _registerMethod(new PreviewWithdrawReentrancyTest());
        _registerMethod(new PreviewWithdrawWithTypeReentrancyTest());
        _registerMethod(new RedeemReentrancyTest());
        _registerMethod(new RedeemWithTypeReentrancyTest());
        _registerMethod(new RepayReentrancyTest());
        _registerMethod(new RepaySharesReentrancyTest());
        _registerMethod(new SharedStorageReentrancyTest());
        _registerMethod(new SiloDataStorageReentrancyTest());
        _registerMethod(new SwitchCollateralToReentrancyTest());
        _registerMethod(new SymbolReentrancyTest());
        _registerMethod(new TotalReentrancyTest());
        _registerMethod(new TotalAssetsReentrancyTest());
        _registerMethod(new TotalSupplyReentrancyTest());
        _registerMethod(new WithdrawReentrancyTest());
        _registerMethod(new WithdrawWithTypeReentrancyTest());
    }

    function supportedMethodsLength() external view returns (uint256) {
        return supportedMethods.length;
    }

    function _registerMethod(IMethodReentrancyTest method) internal {
        methods[method.methodSignature()] = method;
        supportedMethods.push(method.methodSignature());
    }
}
