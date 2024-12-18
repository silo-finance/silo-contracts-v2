Silo Properties
===============

.. index:: SiloProp1

.. describe:: SiloProp1

   **Status:** Working on it

   **Severity:** High

   **Type:**

   Value of collateral shares are only increasing, i.e. the amount of underlying
   collateral tokens represented by :math:`x` shares can only increase.

----

.. index:: SiloProp2

.. describe:: SiloProp2

   **Status:** Working on it

   **Severity:** Critical

   **Type:**

   Any call on :cvl:`Silo0` (and all its tokens and associated contracts) should yield
   the same result as the same call, but with :cvl:`accrueInterest` called before it on
   :cvl:`Sil0`.

   Allowed changes: timestamp, ...

----

.. index:: SiloProp3

.. describe:: SiloProp3

   **Status:** None

   **Severity:** High

   **Type:**

   Accruals happen at the expected interactions.

   .. todo:: Might be a duplicate.

----

.. index:: SiloProp4

.. describe:: SiloProp4

   **Status:** None

   **Severity:** High

   **Type:**

   Deposits should not revert (assuming there were enough funds).

----

.. index:: SiloProp5

.. describe:: SiloProp5

   **Status:** None

   **Severity:** High

   **Type:**

   Deposit that was successful, shouldn’t be front-runabble to revert.

   *Also catches TOB-11*

----

.. index:: SiloProp6

.. describe:: SiloProp6

   **Status:** None

   **Severity:** Med

   **Type:**

   Value of debt shares are only increasing (the amount of underlying collateral tokens
   represented by :math:`x` shares can only increase).

   .. note:: This isn't true, but it might be worthwhile listing where exactly it is violated.

----

.. index:: SiloProp7

.. describe:: SiloProp7

   **Status:** None

   **Severity:** High

   **Type:**

   Balance of a user that has 0 collateral, can’t increase (except deposit or transfer).
   The idea is to see that collateral fees are not somehow accrued for a user with no
   shares.

----

.. index:: SiloProp8

.. describe:: SiloProp8

   **Status:** Reviewed manually

   **Severity:** Critical

   **Type:**

   Silo’s total balance of the collateral token cannot go under the value 
   represented by all the protected collateral shares,
   except in liquidation perhaps?

----

.. index:: SiloProp9

.. describe:: SiloProp9

   **Status:** None

   **Severity:** High

   **Type:**

   If debt of a user > 0 , then the corresponding combined collateral must be > 0.

   Except for liquidated user (LTV above 100% minus liquidation fee).

----

.. index:: SiloProp10

.. describe:: SiloProp10

   **Status:** NA

   **Severity:** 

   **Type:**

   Can’t borrow with 0 collateral.

   .. todo:: Duplicate of ``RA_silo_cant_borrow_without_collateral``.

----

.. index:: SiloProp11

.. describe:: SiloProp11

   **Status:** None

   **Severity:** Critical

   **Type:**

   No user’s shares are worth more than the totals for that asset type.

----

.. index:: SiloProp12

.. describe:: SiloProp12

   **Status:** None

   **Severity:** High

   **Type:**

   Functions that get :cvl:`assetType` should all (currently) revert if the
   :cvl:`assetType` is :cvl:`debtToken`.

----

.. index:: SiloProp13

.. describe:: SiloProp13

   **Status:** None

   **Severity:** Critical

   **Type:**

   Protected funds are not affecting interest rate calculations.

----

.. index:: SiloProp14

.. describe:: SiloProp14

   **Status:** None

   **Severity:** Med

   **Type:**

   Any call On :cvl:`Silo0` (ands all its tokens and associated contracts) Should
   yield the same result as the same call, but with accrueInterest called before it,
   on :cvl:`Silo1`.

----

.. index:: SiloProp15

.. describe:: SiloProp15

   **Status:** None

   **Severity:** Med

   **Type:**

   Any call On :cvl:`Silo0` (ands all its tokens and associated contracts) should yield
   the same result as the same call, but with reentrancy guard enabled before it,
   on :cvl:`Silo1`.

   

----

.. index:: SiloProp16

.. describe:: SiloProp16

   **Status:** None

   **Severity:** Critical

   **Type:**

   A call to :cvl:`deposit()` with amount that is smaller than returned by
   :cvl:`MaxDesposit()` should not revert (for a given user).

   .. todo:: Possible duplicate.

----

.. index:: SiloProp18

.. describe:: SiloProp18

   **Status:** Done

   **Severity:** 

   **Type:** Valid-state

   Invariant - Silo's total collateral assets are at least the total supply of the
   :cvl:`CollateralShare` Token.

----

.. index:: SiloProp19

.. describe:: SiloProp19

   **Status:** Done

   **Severity:** 

   **Type:** Valid-state

   Invariant - Silo's total protected collateral assets are at least the total supply
   of the :cvl:`ShareProtectedCollateral` token.

----

.. index:: SiloProp20

.. describe:: SiloProp20

   **Status:** Done

   **Severity:** High

   **Type:** Valid-state

   Invariant - Silo cannot have assets of any type when the interest rate timestamp is 0.

----

.. index:: SiloProp21

.. describe:: SiloProp21

   **Status:** Done

   **Severity:** Critical

   **Type:** Valid-state

   Invariant - the system is solvent (liquidity property):

   .. warning::

      The formula below is missing *fees* (and interest -- though it is added to both debt
      and collateral)!

   .. math::

      total\_collateral + total\_protected\_collateral - total\_debt \leq balance\_of\_silo\_in\_underlying\_asset

----

.. index:: SiloProp22

.. describe:: SiloProp22

   **Status:** None

   **Severity:** 

   **Type:** 

   After a call to :cvl:`withdrawFee` a user should always be allowed to call
   withdraw of protected assets.

----

.. index:: SiloProp23

.. describe:: SiloProp23

   **Status:** None

   **Severity:** 

   **Type:** 

   Liquidation - liquidator that asked to pay :math:`x` assets can't pay/be charged more
   than :math:`x` assets.
   

----

.. index:: SiloProp24

.. describe:: SiloProp24

   **Status:** None

   **Severity:** 

   **Type:** 

   Liquidation - If the maxmium liquidatable amount was :math:`y` assets, then
   regradless of the number the liquidator was willing to pay, it can't charge them more
   than :math:`y` assets (not entire debt, but amount of debt to cover until the position
   is healthy).

----

.. index:: SiloProp25

.. describe:: SiloProp25

   **Status:** None

   **Severity:** 

   **Type:** 

   Liquidation - If in a given situation paying for :math:`x` assets should yield
   :math:`y` collateral, then no interaction can cause paying :math:`x` assets to get
   less than :math:`y` collaterals.
   
   Might be implemented as a front-run rule on liquidation (and check the amount of
   collateral yielded to the liquidator).

   .. note::
   
      * Might be trivially wrong for extremely indebted positions?
      * can one get 0 collateral back?

----

.. index:: SiloProp26

.. describe:: SiloProp26

   **Status:** None

   **Severity:** 

   **Type:** 

   Preview functions are correct.

   Preview :cvl:`Q` must not promise to the user more than they'd receive by
   calling :cvl:`Q`.
