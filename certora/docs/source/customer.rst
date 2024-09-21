Customer Properties
===================

Unit tests
----------

.. index:: UT_Silo_accrueInterest

.. describe:: UT_Silo_accrueInterest

   **Status:** Done

   **Severity:** High

   **Type:** Unit-test

   :cvl:`accrueInterest` can only be executed on
   :cvl:`deposit`, :cvl:`mint`, :cvl:`withdraw`, :cvl:`redeem`, :cvl:`liquidationCall`,
   :cvl:`accrueInterest`, :cvl:`leverage`, :cvl:`repay` and :cvl:`repayShares`.

   .. dropdown:: Rule

      .. cvlinclude:: @silo-specs/unit-tests/UnitTestsSilo0.spec
         :caption:

----

Variable changes
----------------

.. index:: VC_Silo_total_collateral_increase

.. describe:: VC_Silo_total_collateral_increase

   **Status:** Done

   **Severity:** High

   **Type:** Variable-change

   :cvl:`collateralShareToken.totalSupply` and :cvl:`Silo._total[ISilo.AssetType.Collateral].assets`
   should increase only on :cvl:`deposit`, :cvl:`mint` and :cvl:`transitionCollateral`.

   :cvl:`accrueInterest` increases only :cvl:`Silo._total[ISilo.AssetType.Collateral].assets`.
   The balance of the silo in the underlying asset should increase for the same amount
   as :cvl:`Silo._total[ISilo.AssetType.Collateral].assets` increased.

   .. dropdown:: Rule

      .. cvlinclude:: @silo-specs/variable-changes/VariableChangesSilo0.spec
         :cvlobject: VC_Silo_total_collateral_increase
         :caption:

----

.. index:: VC_Silo_total_collateral_decrease

.. describe:: VC_Silo_total_collateral_decrease

   **Status:** Done

   **Severity:** High
   
   **Type:** Variable-change

   The balance of the silo in the underlying asset should decrease for the same amount
   as :cvl:`Silo._total[ISilo.AssetType.Collateral].assets` decreased,

   .. dropdown:: Rule

      .. cvlinclude:: @silo-specs/variable-changes/VariableChangesSilo0.spec
         :cvlobject: VC_Silo_total_collateral_decrease
         :caption:

----

.. index:: VC_Silo_total_protected_increase

.. describe:: VC_Silo_total_protected_increase

   **Status:** Done

   **Severity:** High
   
   **Type:** Variable-change

   The balance of the silo in the underlying asset should increase for the same amount
   as :cvl:`Silo._total[ISilo.AssetType.Protected].assets` increased.
   :cvl:`accrueInterest` does not increase the protected assets.

----

.. index:: VC_Silo_total_protected_decrease

.. describe:: VC_Silo_total_protected_decrease

   **Status:** Done

   **Severity:** High
   
   **Type:** Variable-change

   The balance of the silo in the underlying asset should decrease for the same amount as
   :cvl:`Silo._total[ISilo.AssetType.Protected].assets` decreased

----

.. index:: VC_Silo_total_debt_increase

.. describe:: VC_Silo_total_debt_increase

   **Status:** Done

   **Severity:** High
   
   **Type:** Variable-change

   The balance of the silo in the underlying asset should decrease for the same amount
   as :cvl:`Silo._total[ISilo.AssetType.Debt].assets` increased.

----

.. index:: VC_Silo_total_debt_decrease

.. describe:: VC_Silo_total_debt_decrease

   **Status:** Done

   **Severity:** High
   
   **Type:** Variable-change

   The balance of the silo in the underlying asset should increase for the same amount as
   :cvl:`Silo._total[ISilo.AssetType.Debt].assets` decreased.

----

.. index:: VC_Silo_siloData_management

.. describe:: VC_Silo_siloData_management

   **Status:** Done

   **Severity:** High
   
   **Type:** Variable-change

   :cvl:`siloData.timestamp` can be increased by :cvl:`accrueInterest` only.

----

.. index:: VC_Silo_debt_share_balance

.. describe:: VC_Silo_debt_share_balance

   **Status:** Done

   **Severity:** High
   
   **Type:** Variable-change

   :cvl:`shareDebtToken.balanceOf(user)` increases/decrease :math:`\implies`
   :cvl:`Silo._total[ISilo.AssetType.Debt].assets` increases/decrease.

----

.. index:: VC_Silo_protected_share_balance

.. describe:: VC_Silo_protected_share_balance

   **Status:** Done

   **Severity:** High
   
   **Type:** Variable-change

   :cvl:`protectedShareToken.balanceOf(user)` increases/decrease :math:`\implies`
   :cvl:`Silo._total[ISilo.AssetType.Protected].assets` increases/decrease.

----

.. index:: VC_Silo_collateral_share_balance

.. describe:: VC_Silo_collateral_share_balance

   **Status:** Done

   **Severity:** High
   
   **Type:** Variable-change

   :cvl:`collateralShareToken.balanceOf(user)` increases/decrease :math:`\implies`
   :cvl:`Silo._total[ISilo.AssetType.Collateral].assets` increases/decrease.

----

Valid states
------------

.. index:: VS_Silo_totals_share_token_totalSupply

.. describe:: VS_Silo_totals_share_token_totalSupply

   **Status:** Done

   **Severity:** High
   
   **Type:** Valid-state

   * :cvl:`Silo._total[ISilo.AssetType.Collateral].assets` is zero :math:`\iff`
     :cvl:`collateralShareToken.totalSupply` is zero.
   * :cvl:`Silo._total[ISilo.AssetType.Protected].assets` is zero :math:`\iff`
     :cvl:`protectedShareToken.totalSupply` is zero.
   * :cvl:`Silo._total[ISilo.AssetType.Debt].assets` is zero :math:`\iff`
     :cvl:`debtShareToken.totalSupply` is zero.

----

.. index:: VS_Silo_interestRateTimestamp_daoAndDeployerFees

.. describe:: VS_Silo_interestRateTimestamp_daoAndDeployerFees

   **Status:** Done

   **Severity:** High
   
   **Type:** Valid-state

   #. :cvl:`_siloData.interestRateTimestamp` is zero :math:`\implies`
      :cvl:`_siloData.daoAndDeployerFees` is zero.
   #. :cvl:`_siloData.daoAndDeployerFees` can increase without
      :cvl:`_siloData.interestRateTimestamp` only on flashLoan fn.

----

.. index:: VS_Silo_totalBorrowAmount

.. describe:: VS_Silo_totalBorrowAmount

   **Status:** Done

   **Severity:** High
   
   **Type:** Valid-state

   :cvl:`Silo._total[ISilo.AssetType.Debt].assets` is not zero
   :math:`\implies` :cvl:`Silo._total[ISilo.AssetType.Collateral].assets` is not zero.

----

.. index:: VS_Silo_debtShareToken_balance_notZero

.. describe:: VS_Silo_debtShareToken_balance_notZero

   **Status:** Done

   **Severity:** High
   
   **Type:** Valid-state

   :cvl:`shareDebtToke.balanceOf(user)` is not zero :math:`\implies`
   :cvl:`protectedShareToken.balanceOf(user) + collateralShareToken.balanceOf(user)` is zero.

----

.. index:: VS_Silo_shareToken_supply_totalAssets_

.. describe:: VS_Silo_shareToken_supply_totalAssets_

   **Status:** Done

   **Severity:** High

   **Type:** Valid-state

   Share token total supply is not 0 :math:`\implies` share token
   total supply :math:`\leq` :cvl:`Silo._total[ISilo.AssetType.*].assets`.

----

.. index:: VS_Silo_balance_totalAssets

.. describe:: VS_Silo_balance_totalAssets

   **Status:** Done

   **Severity:** High

   **Type:** Valid-state

   Balance of the silo should never be less than :cvl:`Silo._total[ISilo.AssetType.Protected].assets`.

----

.. index:: VS_silo_getLiquidity_less_equal_balance

.. describe:: VS_silo_getLiquidity_less_equal_balance

   **Status:** Done

   **Severity:** High

   **Type:** Valid-state

   Available liquidity returned by the :cvl:`getLiquidity` should be less than or equal
   to balance of the actual silo (i.e. assets held by the silo).

----

State transition
----------------

.. index:: ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency

.. describe:: ST_Silo_interestRateTimestamp_totalBorrowAmount_dependency

   **Status:** Done

   **Severity:** High

   **Type:** State-transition

   #. :cvl:`_siloData.interestRateTimestamp` is changed and it was not 0 and 
   #. :cvl:`Silo._total[ISilo.AssetType.Debt].assets` was not 0

   then :cvl:`Silo._total[ISilo.AssetType.Debt].assets` is changed.

----

.. index:: ST_Silo_interestRateTimestamp_totalBorrowAmount_fee_dependency

.. describe:: ST_Silo_interestRateTimestamp_totalBorrowAmount_fee_dependency

   **Status:** Done

   **Severity:** High

   **Type:** State-transition

   #. :cvl:`_siloData.interestRateTimestamp` is changed and it was not 0 and
   #. :cvl:`Silo._total[ISilo.AssetType.Debt].assets` was not 0 and
   #. :cvl:`Silo.getFeesAndFeeReceivers().daoFee` or
      :cvl:`Silo.getFeesAndFeeReceivers().deployerFee` was not 0,

   then :cvl:`_siloData.daoAndDeployerFees` increased.

----

High level properties
---------------------

.. index:: HLP_inverse_deposit_withdraw_collateral

.. describe:: HLP_inverse_deposit_withdraw_collateral

   **Status:** Done

   **Severity:** High

   **Type:** High-level-property

   Inverse deposit - withdraw for collateralToken:
      For any user, the balance before deposit should be equal to the balance after
      depositing and then withdrawing the same amount.
      Silo :cvl:`Silo._total[ISilo.AssetType.*].assets` should be the same.
      Apply for :cvl:`mint`, :cvl:`withdraw`, :cvl:`redeem`, :cvl:`repay`, :cvl:`repayShares`,
      :cvl:`borrow` and :cvl:`borrowShares`.

----

.. index:: HLP_additive_deposit_collateral

.. describe:: HLP_additive_deposit_collateral

   **Status:** NA

   **Severity:** High

   **Type:** High-level-property

   Additive deposit for the state *while do* :cvl:`deposit(x + y)` should be the same as
   :cvl:`deposit(x) + deposit(y)`.
   Apply for :cvl:`mint`, :cvl:`withdraw`, :cvl:`redeem`, :cvl:`repay`, :cvl:`repayShares`,
   :cvl:`borrow` and :cvl:`borrowShares`.
   
   .. todo:: Unclear phrasing in deposit additivity -- verify.

----

.. index:: HLP_integrity_deposit_collateral

.. describe:: HLP_integrity_deposit_collateral

   **Status:** Done

   **Severity:** High

   **Type:** High-level-property

   Integrity of deposit for :cvl:`collateralToken`:
     :cvl:`Silo._total[ISilo.AssetType.Collateral].assets` after deposit should be equal
     to the :cvl:`Silo._total[ISilo.AssetType.Collateral].assets` before deposit plus
     amount of the deposit.
     Apply for :cvl:`mint`, :cvl:`withdraw`, :cvl:`redeem`, :cvl:`repay`, :cvl:`repayShares`,
     :cvl:`borrow`, :cvl:`borrowShares` and :cvl:`transitionCollateral`.

----

.. index:: HLP_deposit_collateral_update_only_recepient

.. describe:: HLP_deposit_collateral_update_only_recepient

   **Status:** Done

   **Severity:** High

   **Type:** High-level-property

   Deposit of the collateral will only update the balance of the recipient.
   Apply for :cvl:`mint, withdraw, redeem, repay, repayShares, borrow, borrowShares`.

----

.. index:: HLP_transition_collateral_update_only_recepient

.. describe:: HLP_transition_collateral_update_only_recepient

   **Status:** Done

   **Severity:** High

   **Type:** High-level-property

   Transition of the collateral will increase one balance and decrease another of only owner.

----

.. index:: HLP_liquidationCall_shares_tokens_balances

.. describe:: HLP_liquidationCall_shares_tokens_balances

   **Status:** None

   **Severity:** Med

   **Type:** High-level-property

   :cvl:`liquidationCall` will only update the balances of the provided user
   (also the liquidator in case of share token).

----

Risk analysis
-------------

.. index:: RA_Silo_no_withdraw_after_withdrawing_all

.. describe:: RA_Silo_no_withdraw_after_withdrawing_all

   **Status:** Done

   **Severity:** High

   **Type:** Risk-analysis

   A user cannot withdraw anything after withdrawing entire balance.

----

.. index:: RA_Silo_no_negative_interest_for_loan

.. describe:: RA_Silo_no_negative_interest_for_loan

   **Status:** Working on it

   **Severity:** High

   **Type:** Risk-analysis

   A user should not be able to fully repay a loan with less amount than he borrowed.

   .. todo:: Are there no edge-cases?

----

.. index:: RA_Silo_repay_all_shares

.. describe:: RA_Silo_repay_all_shares

   **Status:** Done

   **Severity:** High

   **Type:** Risk-analysis

   A user has no debt after being repaid with max shares amount (no dust remains).

----

.. index:: RA_silo_reentrancy_modifier

.. describe:: RA_silo_reentrancy_modifier

   **Status:** Done

   **Severity:** High

   **Type:** Risk-analysis

   :cvl:`NonReentrant` modifier work correctly.

----

.. index:: RA_silo_cant_borrow_without_collateral

.. describe:: RA_silo_cant_borrow_without_collateral

   **Status:** Done

   **Severity:** High

   **Type:** Risk-analysis

   User should not be able to borrow without collateral.

----

.. index:: RA_silo_solvent_after_borrow

.. describe:: RA_silo_solvent_after_borrow

   **Status:** Working on it

   **Severity:** High

   **Type:** Risk-analysis

   User should be solvent after borrowing from the silo.

----

.. index:: RA_silo_solvent_after_repaying

.. describe:: RA_silo_solvent_after_repaying

   **Status:** Working on it

   **Severity:** High

   **Type:** Risk-analysis

   User should be solvent after repaying all.

----

.. index:: RA_zero_assets_iff_zero_shares

.. describe:: RA_zero_assets_iff_zero_shares

   **Status:** Done

   **Severity:** High

   **Type:** Risk-analysis

   For any asset type, its total supply is zero iff the underlying total assets are zero.

----

.. index:: RA_no_collateral_assets_no_debt_assets

.. describe:: RA_no_collateral_assets_no_debt_assets

   **Status:** Done

   **Severity:** High

   **Type:** Risk-analysis

   If there are no collateral assets then there is no debt.

----

.. index:: RA_silo_cant_borrow_more_than_max

.. describe:: RA_silo_cant_borrow_more_than_max

   **Status:** Done

   **Severity:** High

   **Type:** Risk-analysis

   User should not be able to borrow more than :cvl:`maxBorrow().`

----

.. index:: VS_Silo_daoAndDeployerFees_and_totals

.. describe:: VS_Silo_daoAndDeployerFees_and_totals

   **Status:** Done

   **Severity:** Med

   **Type:** Risk-analysis

   Increase in :cvl:`_siloData.daoAndDeployerFees` implies
   increase in :cvl:`Silo._total[ISilo.AssetType.Collateral].assets` and
   :cvl:`Silo._total[ISilo.AssetType.Debt].assets` as well. 

   Moreover, :cvl:`_siloData.interestRateTimestamp` can only increase.

   .. todo::

      :cvl:`daoAndDeployerFees` changed to :cvl:`daoAndDeployerRevenue` -- verify this
      has no meaningful impact.

----

.. index:: HLP_silo_anyone_for_anyone

.. describe:: HLP_silo_anyone_for_anyone

   **Status:** Done

   **Severity:** Med

   **Type:** Risk-analysis

   Anyone can deposit for anyone and anyone can repay anyone.

----

.. index:: HLP_silo_anyone_can_liquidate_insolvent

.. describe:: HLP_silo_anyone_can_liquidate_insolvent

   **Status:** None

   **Severity:** Med

   **Type:** Risk-analysis

   Anyone can liquidate insolvent user.

----

.. index:: RA_Silo_balance_more_than_protected_collateral_deposit

.. describe:: RA_Silo_balance_more_than_protected_collateral_deposit

   **Status:** None

   **Severity:** Med

   **Type:** Risk-analysis

   With protected collateral deposit, there is no scenario where the balance of a
   contract is less than that of the deposit amount.

----

.. index:: RA_Silo_borrowed_asset_not_depositable

.. describe:: RA_Silo_borrowed_asset_not_depositable

   **Status:** NA

   **Severity:** High

   **Type:** Risk-analysis

   A user should not be able to deposit an asset that he borrowed in the Silo.

----

.. index:: RA_Silo_withdraw_all_shares

.. describe:: RA_Silo_withdraw_all_shares

   **Status:** NA

   **Severity:** High

   **Type:** Risk-analysis

   A user can withdraw all with max shares amount and not be able to withdraw more.

----

.. index:: RA_silo_read_only_reentrancy

.. describe:: RA_silo_read_only_reentrancy

   **Status:** NA

   **Severity:** High

   **Type:** Risk-analysis

   Cross silo read-only reentrancy check. Allowed methods for reentrancy: :cvl:`flashLoan`.

   .. todo:: Is this still relevant and correct?

----

.. index:: RA_silo_any_user_can_withdraw

.. describe:: RA_silo_any_user_can_withdraw

   **Status:** Done

   **Severity:** Med

   **Type:** Risk-analysis

   Any depositor can withdraw from the silo.

----

.. index:: RA_silo_cannot_execute_without_approval

.. describe:: RA_silo_cannot_execute_without_approval

   **Status:** None

   **Severity:** High

   **Type:** Risk-analysis

   User can not execute on behalf of an owner such methods as :cvl:`transitionCollateral`,
   :cvl:`withdraw`, :cvl:`redeem`, :cvl:`borrow` and :cvl:`borrowShares` without approval.

----

.. index:: RA_silo_transion_collateral_liquidity

.. describe:: RA_silo_transion_collateral_liquidity

   **Status:** None

   **Severity:** High

   **Type:** Risk-analysis

   User can transition only available liquidity to protected collateral.

----

.. index:: RA_silo_borrow_withdraw_getLiquidity

.. describe:: RA_silo_borrow_withdraw_getLiquidity

   **Status:** None

   **Severity:** High

   **Type:** Risk-analysis

   User is always able to borrow/withdraw amount returned by :cvl:`getLiquidity` function.

----

.. index:: RA_silo_borrow_withdraw_getLiquidity (name wrong? TODO check)

.. describe:: RA_silo_borrow_withdraw_getLiquidity (name wrong? TODO check)

   **Status:** NA

   **Severity:** High

   **Type:** Risk-analysis

   User is always able to withdraw protected collateral up to
   :cvl:`Silo._total[ISilo.AssetType.Protected].assets`.
