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

SiloConfig
----------
We use `linking`_ to connect :cvl:`SiloConfig` immutable addresses to the respective
contracts. For example:

.. cvlinclude:: @silo-configs/valid_states_example.conf
   :start-at: link
   :end-at: ]
   :caption:

----

Base tokens
-----------
Both mock tokens used in the setup, :clink:`Token0<@mocks/Token0.sol>` and 
:clink:`Token1<@mocks/Token1.sol>`, inherit from
:clink:`@openzeppelin/contracts/token/ERC20/ERC20.sol`.

.. attention::

   Note that this is only one paricular ERC-20 implementation. For example, this
   implementation reverts on transfer to address zero or insufficient funds.
   Other implementation may simply return :solidity:`false`.

----

Silos
-----
Both silos inherit from :clink:`SiloHarness<@harness/SiloHarness.sol>`, which
exposes certain functions and data needed for specs.


.. Links
   -----

.. _linking: https://docs.certora.com/en/latest/docs/prover/cli/options.html#link

.. _Single Silo run report:
   https://prover.certora.com/output/98279/f220749cfee749e9aa62576f505672f2?anonymousKey=cc545b62e1aad0cc6809841604784f0049d09eb5
