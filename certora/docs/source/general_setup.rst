Common setup
============

Setup diagram
-------------

.. graphviz:: setup_diagram.dot
   :align: center

----

General notes
-------------
* In CVL, each contract is considered as having a *unique* implementation. So we
  must have separate contract for each token and silo.
* We've added both silos and all 8 tokens to the scene, even when not necessary.
  Using a single silo's contracts did not seem to speed up the Prove,
  see for example `Single Silo run report`_.

----

Contracts
---------

SiloConfig
^^^^^^^^^^
We used `linking`_ to connect :cvl:`SiloConfig` immutable addresses to the respective
contracts. For example:

.. cvlinclude:: @silo-configs/valid_states_example.conf
   :start-at: link
   :end-at: ]
   :caption:

Note that there is a single unique :cvl:`SiloConfig` in the scene, used by all other
contracts.

Base tokens
^^^^^^^^^^^
Both mock tokens used in the setup, :clink:`Token0<@mocks/Token0.sol>` and 
:clink:`Token1<@mocks/Token1.sol>`, inherit from
:clink:`@openzeppelin/contracts/token/ERC20/ERC20.sol`.

.. attention::

   Note that this is only one paricular ERC-20 implementation. For example, this
   implementation reverts on transfer to address zero or insufficient funds.
   Other implementation may simply return :solidity:`false`.

Silos
^^^^^
Both silos inherit from :clink:`SiloHarness<@harness/SiloHarness.sol>`, which
exposes certain functions and data needed for specs.

----

Summaries
---------

SiloConfig
^^^^^^^^^^
For many calls to :cvl:`SiloConfig`, such as the one shown below, we cannot
link a slot to the :cvl:`SiloConfig` contract to resolve the call. Instead we use
:cvl:`DISPATCHER` summaries.

.. cvlinclude:: @lib/Actions.sol
   :start-at: function deposit
   :end-at: siloConfig.accrueInterestForSilo
   :emphasize-lines: 14-
   :caption: :clink:`Call to SiloConfig from Action library<@lib/Actions.sol>`

.. cvlinclude:: @silo-specs/valid_states_example.spec
   :start-at: CrossReentrancyGuard
   :end-at: turnOffReentrancyProtection
   :caption: :clink:`DISPATCHER summary example<@silo-specs/valid_states_example.spec>`

ISiloOracle
^^^^^^^^^^^
* Summarized :solidity:`ISiloOracle.quote` as using a constant price of 1, this is a
  simplification.
* The function :solidity:`beforeQuote` was summarized as :cvl:`NONDET`, which
  essentially ignores any side-effects.

.. attention:: Both summarizations are under approximations.


Mathematical simplification
^^^^^^^^^^^^^^^^^^^^^^^^^^^
We've summarized :solidity:`mulDiv` as a CVL function, which helps reduce the risk
of timeout. For example:

.. cvlinclude:: @silo-specs/valid_states_example.spec
   :cvlobject: cvlMulDiv
   :caption: :clink:`from valid_states_example.spec<@silo-specs/valid_states_example.spec>`

.. attention::

   The summarized function never reverts. Hence this summarization would not be
   appropriate for certain rules, like rules checking revert conditions.

----

Configuration
-------------
* Used Solidity version 0.8.24 throughout.
* Used ``"loop_iter": "2"``.


.. Links
   -----

.. _linking: https://docs.certora.com/en/latest/docs/prover/cli/options.html#link

.. _Single Silo run report:
   https://prover.certora.com/output/98279/f220749cfee749e9aa62576f505672f2?anonymousKey=cc545b62e1aad0cc6809841604784f0049d09eb5
