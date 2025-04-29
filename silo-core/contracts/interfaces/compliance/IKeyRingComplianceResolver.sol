// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IComplianceResolver} from "silo-core/contracts/interfaces/compliance/IComplianceResolver.sol";
import {IKeyringChecker} from "silo-core/contracts/interfaces/compliance/IKeyringChecker.sol";

/**
  ---   ACTIONS --- | ------------ PRE CONDITIONS ------------ 
     Hook action           HasDebt, DepositType, AddressType

  Examples:

  - withdraw => has debt, deposit type borrowable, withdraw receiver
  - withdraw => has debt, deposit type borrowable, tx sender

  - deposit => not configured, deposit type borrowable, withdraw receiver
  - deposit => not configured, deposit type borrowable, tx sender

  Hook actions:
  - deposit
  - borrow
  - borrow same asset
  - repay
  - withdraw
  - flash loan
  - transition collateral
  - switch collateral
  - liquidation
  - share collateral token transfer
  - share protected collateral token transfer
  - share debt token transfer
 */
interface IKeyRingComplianceResolver is IComplianceResolver {
    enum ComplianceCheck {
        // By design, if compliance check is not configured, we expect compliance hook to revert
        notConfigured,
        checkCompliance,
        skipCompliance
    }

    enum HasDebt {
        any,
        noDebt,
        hasDebtToken0,
        hasDebtToken1
    }

    enum DepositType {
        any,
        nonBorrowable,
        borrowable
    }

    enum AddressType {
        notConfigured, // AddressType is required for the policy config
        all, // check all addresses involved in the action
        transactionSender,
        depositReceiver,
        borrowReceiver,
        borrowSameAssetReceiver,
        repayBorrower,
        withdrawReceiver,
        flashLoanReceiver,
        transitionCollateralOwner,
        liquidationBorrower,
        shareCollateralTokenTransferReceiver,
        shareProtectedCollateralTokenTransferReceiver,
        shareDebtTokenTransferReceiver
    }

    // Pre condition for the policy verification
    struct ActionPolicyPreConditions {
        HasDebt hasDebt;
        DepositType depositType;
        AddressType addressType;
    }

    struct ActionPolicyConfig {
        ComplianceCheck complianceCheck; // shows if we want to check compliance
        ActionPolicyPreConditions preConditions;
        uint256 keyRingPolicyId;
    }

    /// @notice Set the policy for the actions.
    /// @param _actions The actions to set the policy for.
    /// @param _configs The policy configurations to set.
    /// @dev Should update hook config.
    function setPolicy(uint256[] calldata _actions, ActionPolicyConfig[] memory _configs) external;

    /// @notice Set the policy for the action.
    /// @dev It applies default values for the pre conditions.
    /// @param _action The action to set the policy for.
    /// @param _policyId The policy id to set.
    /// @dev Should update hook config.
    function setPolicy(uint256 _action, uint256 _policyId) external;

    /// @notice Get the policy for the action.
    /// @param _action The action to get the policy for.
    /// @dev If the policy is not set for the action it will return 0.
    function policiesConfigsForAction(uint256 _action) external view returns (ActionPolicyConfig[] memory configs);

    /// @notice Get the keyring checker.
    /// @return checker The keyring checker.
    function KEYRING_CHECKER() external view returns (IKeyringChecker checker);
}
