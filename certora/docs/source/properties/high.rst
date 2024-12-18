High level properties
---------------------

.. index:: HLP1

.. describe:: HLP1

   **Status:** Working on it

   **Severity:** Critical

   **Type:** High-level-property

   A solvent user is always solvent after interaction (regardless of interacting user).

----

.. index:: HLP2

.. describe:: HLP2

   **Status:** Working on it

   **Severity:** Critical

   **Type:** High-level-property

   Liquidatable / Insolvent user cannot borrow.   

----

.. index:: HLP3

.. describe:: HLP3

   **Status:** Working on it

   **Severity:** Critical

   **Type:** High-level-property

   User should not become atomically liquidatable, meaning:

   .. code-block:: cvl
      :caption: Rule in pseudo-code

      rule (method f, env e){
          accrue rates;
          require (user was healthy);

          f(e, args);

          assert (user is still healthy);
      }

   If you borrow you won't be liquidated in the next block **if configured correctly**
   (margin to liquidation threshold). As is this rule should not work.

   To become liquidatable: price and interest change.

----

.. index:: HLP4

.. describe:: HLP4

   **Status:** Done

   **Severity:** Critical

   **Type:** High-level-property

   Can’t transfer collateral to become insolvent/liquidatable.


----

.. index:: HLP5

.. describe:: HLP5

   **Status:** Done

   **Severity:** High

   **Type:** High-level-property

   One user action should not lower the “health” factor of another user
   (filter out debt transfers).

   .. note::

      Also might be violated due to collateral value lowering?
      (see violated property deposit can't lower share rate).

----

.. index:: HLP6

.. describe:: HLP6

   **Status:** Done

   **Severity:** High

   **Type:** High-level-property

   Preservation of value:
      A user's shares' value (in tokens) plus user's token balance must be preserved
      (up to 2 uints).

----

.. index:: HLP7

.. describe:: HLP7

   **Status:** NA

   **Severity:** Critical

   **Type:** High-level-property

   Equity per share (assets-share ratio) cannot decrease.

   .. todo:: Possible duplicate.

----

.. index:: HLP8

.. describe:: HLP8

   **Status:** NA

   **Severity:** 

   **Type:** High-level-property

   Self liquidation and repaying debt should be the same.

   There should never be an advantage to self liquidate or self repay, the end debt and
   collateral values on both silos should be the same

----

.. index:: HLP9

.. describe:: HLP9

   **Status:** NA

   **Severity:** 

   **Type:** High-level-property

   Once all debt is paid all and all fees are paid *all* users can exit silo.
