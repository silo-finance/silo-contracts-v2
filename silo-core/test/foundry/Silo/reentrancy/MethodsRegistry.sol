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
