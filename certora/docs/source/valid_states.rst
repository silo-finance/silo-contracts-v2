Valid states example
====================
:clink:`Spec file: valid_states_example.spec<@silo-specs/valid_states_example.spec>`

Setup notes
-----------
* Regarding :solidity:`ShareToken._afterTokenTransfer`, I ended not summarizing it.
  This cause some timeouts, but they were mitigated by running each rule separately.
* The function :solidity:`SiloSolvencyLib.isSolvent` was summarized using a ghost
  function and a ghost variable. This simplifies the calculations for the Prover,
  while keeping the result accessible in the ghost variable :cvl:`solvency_ghost`.
* The ERC20 functions :solidity:`name()` and :solidity:`symbol()` received a
  :cvl:`PER_CALLEE_CONSTANT DELETE` summary. The :cvl:`DELETE` summary removes these
  functions from the Prover's optimizations. This was done since these functions caused
  memory partitioning problems.
* I used all three tokens: :cvl:`Silo0`, :cvl:`ShareDebtToken0`,
  and :cvl:`ShareProtectedCollateralToken0` as parametric contracts.

.. todo::

   Is the summary of :solidity:`SiloSolvencyLib.isSolvent` good enough?

Rules and results
-----------------

Reports:
^^^^^^^^
* `VS_Silo_interestRateTimestamp_daoAndDeployerRevenue Report`_
* `VS_Silo_totalBorrowAmount Report`_
* `VS_Silo_totalBorrowAmount_invariant Report`_
* `VS_Silo_totalBorrowAmount_stronger_invariant Report`_

----

.. index:: VS_Silo_interestRateTimestamp_daoAndDeployerRevenue

.. describe:: VS_Silo_interestRateTimestamp_daoAndDeployerRevenue

   **Severity:** High
   
   **Type:** Valid-state

   **Implementation status:** Done

   **Verification status:** Verified / Sanity failed

   **Rule report:** `VS_Silo_interestRateTimestamp_daoAndDeployerRevenue Report`_

   Property:
      #. :cvl:`_siloData.interestRateTimestamp` is zero :math:`\implies`
         :cvl:`_siloData.daoAndDeployerFees` is zero.
      #. :cvl:`_siloData.daoAndDeployerFees` can increase without
         :cvl:`_siloData.interestRateTimestamp` only on flashLoan function.
   
   Functions which faild sanity:
      * :cvl:`ShareDebtToken0.burn(address,address,uint256)`
      * :cvl:`ShareDebtToken0.mint(address,address,uint256)`
      * :cvl:`ShareDebtToken0.synchronizeHooks(uint24,uint24)`
      * :cvl:`ShareProtectedCollateralToken0.burn(address,address,uint256)`
      * :cvl:`ShareProtectedCollateralToken0.forwardTransferFromNoChecks(address,address,uint256)`
      * :cvl:`ShareProtectedCollateralToken0.mint(address,address,uint256)`
      * :cvl:`ShareProtectedCollateralToken0.synchronizeHooks(uint24,uint24)`
      * :cvl:`Silo0.accrueInterestForConfig(address,uint256,uint256)`
      * :cvl:`Silo0.initialize(address)`

   .. important::

      Filtered out functions:

      #. :solidity:`flashLoan`.
      #. :solidity:`callOnBehalfOfSilo` -- contains a :solidity:`delegatecall`.
      #. :solidity:`withdrawFees` -- fails sanity check, possibly because
         :solidity:`withdrawFees` reverts if fees are zero.

   .. todo:: Is filtering out :solidity:`callOnBehalfOfSilo` sound?

   .. dropdown:: Rule

      .. cvlinclude:: @silo-specs/valid_states_example.spec
         :cvlobject: VS_Silo_interestRateTimestamp_daoAndDeployerRevenue
         :caption: :clink:`Rule link<@silo-specs/valid_states_example.spec>`

----

.. index:: VS_Silo_totalBorrowAmount

.. describe:: VS_Silo_totalBorrowAmount

   **Severity:** High
   
   **Type:** Valid-state

   **Implementation status:** Done

   **Verification status:** Violated

   **Rule report:** `VS_Silo_totalBorrowAmount Report`_

   Property:
      :cvl:`Silo._total[ISilo.AssetType.Debt].assets` is not zero
      :math:`\implies` :cvl:`Silo._total[ISilo.AssetType.Collateral].assets` is not zero.

   Violated functions:
      * :cvl:`Silo0.leverageSameAsset(uint256,uint256,address,ISilo.CollateralType)`

   Functions which faild sanity:
      The following functions fail sanity, possibly because the rule requires both
      total debt and total collateral to be zero:

      * :cvl:`ShareDebtToken0.burn(address,address,uint256)`
      * :cvl:`ShareDebtToken0.mint(address,address,uint256)`
      * :cvl:`ShareDebtToken0.synchronizeHooks(uint24,uint24)`
      * :cvl:`ShareProtectedCollateralToken0.burn(address,address,uint256)`
      * :cvl:`ShareProtectedCollateralToken0.forwardTransferFromNoChecks(address,address,uint256)`
      * :cvl:`ShareProtectedCollateralToken0.mint(address,address,uint256)`
      * :cvl:`ShareProtectedCollateralToken0.synchronizeHooks(uint24,uint24)`
      * :cvl:`Silo0.accrueInterestForConfig(address,uint256,uint256)`
      * :cvl:`Silo0.borrow(uint256,address,address)`
      * :cvl:`Silo0.borrowSameAsset(uint256,address,address)`
      * :cvl:`Silo0.borrowShares(uint256,address,address)`
      * :cvl:`Silo0.initialize(address)`
      * :cvl:`Silo0.repay(uint256,address)`

   .. error::

      The rule is violated for :solidity:`leverageSameAsset`.

   .. tip:: This rule is better phrased as an *invariant*, see below.

   .. note::

      Filtered out functions:

      #. :solidity:`callOnBehalfOfSilo` -- contains a :solidity:`delegatecall`.
      #. :solidity:`withdraw` and :solidity:`redeem` fail sanity -- probably since
         the rule requires total debt and total collateral to be zero.

   .. dropdown:: Rule

      .. cvlinclude:: @silo-specs/valid_states_example.spec
         :cvlobject: VS_Silo_totalBorrowAmount
         :caption: :clink:`Rule link<@silo-specs/valid_states_example.spec>`

----

.. index:: VS_Silo_totalBorrowAmount_invariant

.. describe:: VS_Silo_totalBorrowAmount_invariant

   **Severity:** High
   
   **Type:** Valid-state

   **Implementation status:** Done

   **Verification status:** Violated

   **Rule report:** `VS_Silo_totalBorrowAmount_invariant Report`_

   This rule is a rephrasing as an invariant of the rule :cvl:`VS_Silo_totalBorrowAmount`
   above

   Violated functions:
      * :cvl:`Silo0.leverageSameAsset(uint256,uint256,address,ISilo.CollateralType)`

   Functions which faild sanity:
      * :cvl:`ShareDebtToken0.burn(address,address,uint256)`
      * :cvl:`ShareDebtToken0.mint(address,address,uint256)`
      * :cvl:`ShareDebtToken0.synchronizeHooks(uint24,uint24)`
      * :cvl:`ShareProtectedCollateralToken0.burn(address,address,uint256)`
      * :cvl:`ShareProtectedCollateralToken0.forwardTransferFromNoChecks(address,address,uint256)`
      * :cvl:`ShareProtectedCollateralToken0.mint(address,address,uint256)`
      * :cvl:`ShareProtectedCollateralToken0.synchronizeHooks(uint24,uint24)`
      * :cvl:`Silo0.accrueInterestForConfig(address,uint256,uint256)`
      * :cvl:`Silo0.initialize(address)`

   .. error::

      The rule is violated for :solidity:`leverageSameAsset`.

   .. important::

      Filtered out functions:

      #. :solidity:`callOnBehalfOfSilo` -- contains a :solidity:`delegatecall`.

   .. dropdown:: Rule

      .. cvlinclude:: @silo-specs/valid_states_example.spec
         :cvlobject: VS_Silo_totalBorrowAmount_invariant
         :caption: :clink:`Rule link<@silo-specs/valid_states_example.spec>`

----

.. index:: VS_Silo_totalBorrowAmount_stronger_invariant

.. describe:: VS_Silo_totalBorrowAmount_stronger_invariant

   **Severity:** NA
   
   **Type:** Valid-state

   **Implementation status:** Done

   **Verification status:** Verified

   **Rule report:** `VS_Silo_totalBorrowAmount_stronger_invariant Report`_

   Property:
      Total collateral assets :math:`\geq` total debt assets.
      This is a much stronger property than above, and it is in fact violated by
      many functions.

   Filtered out functions:
      The following functions violate the property and were therefore filtered out.

      * :cvl:`_accrueInterest_orig()`
      * :cvl:`_callAccrueInterestForAsset_orig(address,uint256,uint256,address)`
      * :cvl:`accrueInterest()`
      * :cvl:`accrueInterestForConfig(address,uint256,uint256)`
      * :cvl:`deposit(uint256,address)`
      * :cvl:`deposit(uint256,address,ISilo.CollateralType)`
      * :cvl:`leverageSameAsset(uint256,uint256,address,ISilo.CollateralType)`
      * :cvl:`mint(uint256,address)`
      * :cvl:`mint(uint256,address,ISilo.CollateralType)`
      * :cvl:`redeem(uint256,address,address,ISilo.CollateralType)`
      * :cvl:`repay(uint256,address)`
      * :cvl:`repayShares(uint256,address)`
      * :cvl:`switchCollateralToThisSilo()`
      * :cvl:`transitionCollateral(uint256,address,ISilo.CollateralType)`
      * :cvl:`withdraw(uint256,address,address,ISilo.CollateralType)`
      * :cvl:`withdrawFees()`

   .. dropdown:: Rule

      .. cvlinclude:: @silo-specs/valid_states_example.spec
         :cvlobject: VS_Silo_totalBorrowAmount_stronger_invariant
         :caption: :clink:`Rule link<@silo-specs/valid_states_example.spec>`

.. Links
   -----

.. _Valid states report (summarized):
   https://prover.certora.com/output/98279/9f730c09a5be4f3bbfa1f62d428cbee6?anonymousKey=92b46352d6a0e6c2d0e748c1bc7ea6f2c375d441

.. _Valid states report (un-summarized):
   https://prover.certora.com/output/98279/d527985964ed432187af3aa2fc72c9fe?anonymousKey=ca16cd051507b46d328fa2c93e01fdb187b1445b

.. _VS_Silo_totalBorrowAmount Report:
   https://prover.certora.com/output/98279/54098d2e21c141f381f84e9cee735495?anonymousKey=9f9f7c1663731de0df4011159be9c6d44582658a

.. _VS_Silo_totalBorrowAmount_invariant Report:
   https://prover.certora.com/output/98279/a67affb5e5d34f4da309cc6373f43315?anonymousKey=6d36a01cb7effa2f361dabb62be18d80561b5c71

.. _VS_Silo_totalBorrowAmount_stronger_invariant Report:
   https://prover.certora.com/output/98279/afba4d403e324a588eab52ee285dc29e?anonymousKey=02906961e4ea2f494508355eb3feb7595fbef6e1

.. _VS_Silo_interestRateTimestamp_daoAndDeployerRevenue Report:
   https://prover.certora.com/output/98279/2b11e834180844cab36591039ea64cf7?anonymousKey=1c140ce55e08debeb7676c9686e33399de6376f3
