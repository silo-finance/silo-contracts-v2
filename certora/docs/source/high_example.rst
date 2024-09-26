High level example
==================
:clink:`Main spec file high_level_example.spec<@silo-specs/high_level_example.spec>`

Setup notes
-----------

Summaries
^^^^^^^^^

Simplification of interest rate model
"""""""""""""""""""""""""""""""""""""
The main spec uses the summaries in
:clink:`SimplifiedGetCompoundInterestRateAndUpdate.spec<@specs/_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec>`,
which essentially summarizes the :solidity:`IInterestRateModel` in CVL as some
monotonic non-decreasing function of time-diff, bounded by :math:`2^{16} \cdot 10^{18}`.

.. attention:: 

   This summary does not revert, therefore it is inappropriate for rules checking
   revert conditions.

----

CVL implementation of ERC-20s
"""""""""""""""""""""""""""""
The main spec uses the summaries in :clink:`erc20cvl.spec<@specs/erc20cvl.spec>`.
This is an implementation of multiple ERC-20 contracts in CVL, intended for simplifying
the code for the Prover.

* The storage is mimicked by ghost variables.
* Only external functions were summarized - this relies on a lack of any internal
  calls to public functions. Any such calling function *must be summarized*.
  
  .. attention:: This must be checked whenever the code changes.

* As above, these summaries do not revert, and are therefore inappropriate for
  checking reverts.

----

SiloConfig simplification
"""""""""""""""""""""""""
The main spec uses
:clink:`SiloConfigSummarizations.spec<@silo-specs/_common/SiloConfigSummarizations.spec>`.
This simplifies the functions:

* :solidity:`siloConfig.getAssetForSilo`
* :solidity:`siloConfig.getSilos`
* :solidity:`siloConfig.getShareTokens`
* :solidity:`siloConfig.getFeesWithAsset`

Note that these are all :cvl:`DELETE` summaries. This removes the relevant functions from
Prover optimizations, and also prevents calling them from CVL.

----

Configuration
^^^^^^^^^^^^^
* ``"multi_assert_check": true`` -- Runs each CVL :cvl:`assert` statement as a separate
  rule. This is necessary to prevent timeouts.

----

Rules and results
-----------------

Reports
^^^^^^^
* `HLP_mint_breakingUpNotBeneficial_full Report`_
* `HLP_DepositRedeemNotProfitable Report`_

----

.. index:: HLP_mint_breakingUpNotBeneficial_full

.. describe:: HLP_mint_breakingUpNotBeneficial_full

   **Severity:** High
   
   **Type:** High-level

   **Implementation status:** Done

   **Verification status:** Partial (one assertion times out)

   **Rule report:** `HLP_mint_breakingUpNotBeneficial_full Report`_ 

   Property:
      Minting amount :math:`a` followed by amount :math:`b` has no advantage over
      minting once amount :math:`a+b`.

      To start we have:
   
      * :math:`T_0` -- the balance of :cvl:`msg.sender` in :cvl:`token0` at start.
      * :math:`C_0` -- the balance of :cvl:`msg.sender` in :cvl:`shareCollateralToken0` at start.
      * :math:`P_0` -- the balance of :cvl:`msg.sender` in :cvl:`shareProtectedCollateralToken0`
        at start.
   
      The balances after minting amount :math:`s` are:
   
      * :math:`T_s` -- new balance in :cvl:`token0` at start.
      * :math:`C_s` -- new balance in :cvl:`shareCollateralToken0` at start.
      * :math:`P_s` -- new balance in :cvl:`shareProtectedCollateralToken0` at start.
   
      After minting amounts :math:`s_1` and :math:`s_2` (where :math:`s_1 + s_2 = s`):
   
      * :math:`T_q` -- new balance in :cvl:`token0` at start.
      * :math:`C_q` -- new balance in :cvl:`shareCollateralToken0` at start.
      * :math:`P_q` -- new balance in :cvl:`shareProtectedCollateralToken0` at start.
   
      The rule contains two assertions:
   
      #. Either :math:`T_q - T_0 < T_s - T_0` or
   
         * :math:`C_q - C_0 \leq C_s - C_0 + 1` and
         * :math:`P_q - P_0 \leq P_s - P_0 + 1`.
   
      #. Either:
   
         * :math:`C_q - C_0 < C_s - C_0` or
         * :math:`P_q - P_0 < P_s - P_0` or
         * :math:`T_q - T_0 \leq T_s - T_0`.

   .. attention::

      Only the first assertion is verified, the second times out.

   .. dropdown:: Rule

      .. cvlinclude:: @silo-specs/high_level_example.spec
         :cvlobject: HLP_mint_breakingUpNotBeneficial_full
         :caption: :clink:`Rule link<@silo-specs/high_level_example.spec>`

----

.. index:: HLP_DepositRedeemNotProfitable

.. describe:: HLP_DepositRedeemNotProfitable

   **Severity:** High
   
   **Type:** High-level

   **Implementation status:** Done

   **Verification status:** Partial (one assertion times out)

   **Rule report:** `HLP_DepositRedeemNotProfitable Report`_ 

   Property:
      User should not profit by depositing and immediately redeeming.

   .. dropdown:: Rule

      .. cvlinclude:: @silo-specs/high_level_example.spec
         :cvlobject: HLP_DepositRedeemNotProfitable
         :caption: :clink:`Rule link<@silo-specs/high_level_example.spec>`

.. Links
   -----

.. _High Level Properties Rule Report:
   https://prover.certora.com/output/98279/2a009183589f4bf3a1ec79d1f428d2bb?anonymousKey=18a7c2d975a57eff094b298ddc9fbc839b953d05

.. _HLP_mint_breakingUpNotBeneficial_full Report:
   https://prover.certora.com/output/98279/a9e0eab59ef84fbcbe0960b5d192604c?anonymousKey=8e168e2caa140b64e6b8dbdae4eccbb136824084

.. _HLP_DepositRedeemNotProfitable Report:
   https://prover.certora.com/output/98279/f857e287af234a62b5ec67d6a51e74e9?anonymousKey=642e6bb62e1f8b7963572774c1b66082f0e9f088
