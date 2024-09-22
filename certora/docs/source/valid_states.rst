Valid states example
====================
:clink:`Spec file: valid_states_example.spec<@silo-specs/valid_states_example.spec>`

Setup notes
-----------
* Summarized :solidity:`ISiloOracle.quote` as using a constant price of 1 -- a
  simplification.
* Summarized :solidity:`ShareToken._afterTokenTransfer` as constant. This is an
  **under-approximation** since it simply ignores all side-effects of this function.
  However leaving the call to :solidity:`IHookReceiver` unresolved caused havoc issues.
* The function :solidity:`SiloSolvencyLib.isSolvent` was summarized using a ghost
  function and a ghost variable. This simplifies the calculations for the Prover,
  while keeping the result accessible in the ghost variable :cvl:`solvency_ghost`.
* The ERC20 functions :solidity:`name()` and :solidity:`symbol()` received a
  :cvl:`PER_CALLEE_CONSTANT DELETE` summary. The :cvl:`DELETE` summary removes these
  functions from the Prover's optimizations. This was done since these functions caused
  memory partitioning problems.
* The configuration file
  :clink:`valid_states_example.conf<@silo-configs/valid_states_example.conf>` uses
  the latest *master* branch of the Prover: ``"prover_version": "master"``. Because we
  need some recent features not yet released (otherwise some summaries will not be
  applied).

.. todo::

   Is the summary of :solidity:`SiloSolvencyLib.isSolvent` good enough?

Rules and results
-----------------
Report link: `Rule Report`_.

.. index:: VS_Silo_interestRateTimestamp_daoAndDeployerRevenue

.. describe:: VS_Silo_interestRateTimestamp_daoAndDeployerRevenue

   **Severity:** High
   
   **Type:** Valid-state

   **Implementation status:** Done

   **Verification status:** Verified

   **Rule report:** `Rule Report`_

   Property:
      #. :cvl:`_siloData.interestRateTimestamp` is zero :math:`\implies`
         :cvl:`_siloData.daoAndDeployerFees` is zero.
      #. :cvl:`_siloData.daoAndDeployerFees` can increase without
         :cvl:`_siloData.interestRateTimestamp` only on flashLoan function.

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

   **Rule report:** `Rule Report`_

   Property:
      :cvl:`Silo._total[ISilo.AssetType.Debt].assets` is not zero
      :math:`\implies` :cvl:`Silo._total[ISilo.AssetType.Collateral].assets` is not zero.

   .. error::

      The rule is violated for :solidity:`leverageSameAsset`.

   .. tip:: This rule is better phrased as an *invariant*, see below.

   .. caution::

      The following functions fail sanity, possibly because the rule requires both
      total debt and total collateral to be zero:
      :solidity:`borrowSameAsset`, :solidity:`borrow`, :solidity:`borrowShares`
      and :solidity:`repay`.

   .. important::

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

   **Rule report:** `Rule Report`_

   This rule is a rephrasing as an invariant of the rule :cvl:`VS_Silo_totalBorrowAmount`
   above

   .. error::

      The rule is violated for :solidity:`leverageSameAsset`.

   .. important::

      Filtered out functions:

      #. :solidity:`callOnBehalfOfSilo` -- contains a :solidity:`delegatecall`.

   .. dropdown:: Rule

      .. cvlinclude:: @silo-specs/valid_states_example.spec
         :cvlobject: VS_Silo_totalBorrowAmount_invariant
         :caption: :clink:`Rule link<@silo-specs/valid_states_example.spec>`



.. Links
   -----

.. _Rule Report:
   https://prover.certora.com/output/98279/bcf378e7addb4ed0a4708eaa5e54222e?anonymousKey=87ace563ed5d962265e7375bdc44bed1682d0d21
