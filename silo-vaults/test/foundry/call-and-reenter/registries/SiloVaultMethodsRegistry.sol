// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/interfaces/IMethodReentrancyTest.sol";
import {IMethodsRegistry} from "silo-core/test/foundry/Silo/reentrancy/interfaces/IMethodsRegistry.sol";

import {SetCuratorReentrancyTest} from "../methods/SetCuratorReentrancyTest.sol";
import {DecimalsReentrancyTest} from "../methods/DecimalsReentrancyTest.sol";
import {DepositReentrancyTest} from "../methods/DepositReentrancyTest.sol";
import {WithdrawQueueLengthTest} from "../methods/WithdrawQueueLengthTest.sol";
import {WithdrawQueueTest} from "../methods/WithdrawQueueTest.sol";
import {TotalSupplyTest} from "../methods/TotalSupplyTest.sol";
import {TotalAssetsTest} from "../methods/TotalAssetsTest.sol";
import {TimelockTest} from "../methods/TimelockTest.sol";
import {SymbolTest} from "../methods/SymbolTest.sol";
import {SupplyQueueLengthTest} from "../methods/SupplyQueueLengthTest.sol";
import {SupplyQueueTest} from "../methods/SupplyQueueTest.sol";
import {SkimRecipientTest} from "../methods/SkimRecipientTest.sol";
import {PreviewWithdrawTest} from "../methods/PreviewWithdrawTest.sol";
import {PreviewRedeemTest} from "../methods/PreviewRedeemTest.sol";
import {ReentrancyGuardEnteredTest} from "../methods/ReentrancyGuardEnteredTest.sol";
import {PreviewMintTest} from "../methods/PreviewMintTest.sol";
import {PreviewDepositTest} from "../methods/PreviewDepositTest.sol";
import {PendingTimelockTest} from "../methods/PendingTimelockTest.sol";
import {PendingOwnerTest} from "../methods/PendingOwnerTest.sol";
import {PendingGuardianTest} from "../methods/PendingGuardianTest.sol";
import {PendingCapTest} from "../methods/PendingCapTest.sol";
import {OwnerTest} from "../methods/OwnerTest.sol";
import {NoncesTest} from "../methods/NoncesTest.sol";
import {NameTest} from "../methods/NameTest.sol";
import {MaxWithdrawTest} from "../methods/MaxWithdrawTest.sol";
import {MaxRedeemTest} from "../methods/MaxRedeemTest.sol";
import {MaxMintTest} from "../methods/MaxMintTest.sol";
import {MaxDepositTest} from "../methods/MaxDepositTest.sol";
import {LastTotalAssetsTest} from "../methods/LastTotalAssetsTest.sol";
import {IsAllocatorTest} from "../methods/IsAllocatorTest.sol";
import {GuardianTest} from "../methods/GuardianTest.sol";
import {FeeRecipientTest} from "../methods/FeeRecipientTest.sol";
import {FeeTest} from "../methods/FeeTest.sol";
import {EIP712Domain} from "../methods/EIP712Domain.sol";
import {CuratorTest} from "../methods/CuratorTest.sol";
import {ConvertToSharesTest} from "../methods/ConvertToSharesTest.sol";
import {ConvertToAssetsTest} from "../methods/ConvertToAssetsTest.sol";
import {ConfigTest} from "../methods/ConfigTest.sol";
import {BalanceOfTest} from "../methods/BalanceOfTest.sol";
import {AssetTest} from "../methods/AssetTest.sol";
import {AllowanceTest} from "../methods/AllowanceTest.sol";
import {IncentivesModuleTest} from "../methods/IncentivesModuleTest.sol";
import {DecimalsOffsetTest} from "../methods/DecimalsOffsetTest.sol";
import {DomainSeparatorTest} from "../methods/DomainSeparatorTest.sol";

contract SiloVaultMethodsRegistry is IMethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new SetCuratorReentrancyTest());
        _registerMethod(new DecimalsReentrancyTest());
        _registerMethod(new DepositReentrancyTest());
        _registerMethod(new WithdrawQueueLengthTest());
        _registerMethod(new WithdrawQueueTest());
        _registerMethod(new TotalSupplyTest());
        _registerMethod(new TotalAssetsTest());
        _registerMethod(new TimelockTest());
        _registerMethod(new SymbolTest());
        _registerMethod(new SupplyQueueLengthTest());
        _registerMethod(new SupplyQueueTest());
        _registerMethod(new SkimRecipientTest());
        _registerMethod(new PreviewDepositTest());
        _registerMethod(new PreviewMintTest());
        _registerMethod(new PreviewWithdrawTest());
        _registerMethod(new PreviewRedeemTest());
        _registerMethod(new ReentrancyGuardEnteredTest());
        _registerMethod(new PendingTimelockTest());
        _registerMethod(new PendingOwnerTest());
        _registerMethod(new PendingGuardianTest());
        _registerMethod(new PendingCapTest());
        _registerMethod(new OwnerTest());
        _registerMethod(new NoncesTest());
        _registerMethod(new NameTest());
        _registerMethod(new MaxWithdrawTest());
        _registerMethod(new MaxRedeemTest());
        _registerMethod(new MaxMintTest());
        _registerMethod(new MaxDepositTest());
        _registerMethod(new LastTotalAssetsTest());
        _registerMethod(new IsAllocatorTest());
        _registerMethod(new GuardianTest());
        _registerMethod(new FeeRecipientTest());
        _registerMethod(new FeeTest());
        _registerMethod(new EIP712Domain());
        _registerMethod(new CuratorTest());
        _registerMethod(new ConvertToSharesTest());
        _registerMethod(new ConvertToAssetsTest());
        _registerMethod(new ConfigTest());
        _registerMethod(new BalanceOfTest());
        _registerMethod(new AssetTest());
        _registerMethod(new AllowanceTest());
        _registerMethod(new IncentivesModuleTest());
        _registerMethod(new DecimalsOffsetTest());
        _registerMethod(new DomainSeparatorTest());
    }

    function supportedMethodsLength() external view returns (uint256) {
        return supportedMethods.length;
    }

    function abiFile() external pure virtual returns (string memory) {
        return "/cache/foundry/out/silo-vaults/SiloVault.sol/SiloVault.json";
    }

    function _registerMethod(IMethodReentrancyTest method) internal {
        methods[method.methodSignature()] = method;
        supportedMethods.push(method.methodSignature());
    }
}