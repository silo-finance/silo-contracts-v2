Miscellaneous Properties
========================

ShareToken.sol Properties
^^^^^^^^^^^^^^^^^^^^^^^^^

.. index:: ShareToken1

.. describe:: ShareToken1

   **Status:** None

   **Severity:** Med

   For any token, any change in any balance should always call _beforeTransfer()

   

----

.. index:: ShareToken2

.. describe:: ShareToken2

   **Status:** None

   **Severity:** Med

   ERC20 property of total_supply matching all share balances

   

----

.. index:: ShareToken3

.. describe:: ShareToken3

   **Status:** None

   **Severity:** Med

   Can’t re-init

   

----

ShareDebtToken Properties
^^^^^^^^^^^^^^^^^^^^^^^^^

.. index:: ShareDebtToken1

.. describe:: ShareDebtToken1

   **Status:** None

   **Severity:** Med

   ERC20 property of total_supply matching all share balances

   

----

.. index:: ShareDebtToken2

.. describe:: ShareDebtToken2

   **Status:** None

   **Severity:** High

   Debt token cannot be sent away to users that don’t approve it

   

----

.. index:: ShareDebtToken3

.. describe:: ShareDebtToken3

   **Status:** None

   **Severity:** Med

   Debt tokens cannot be sent away to users to make them insolvent (this should be covered by the high level rule - 1)

   

----

SiloConfig Properties
^^^^^^^^^^^^^^^^^^^^^

.. index:: SiloConfig1

.. describe:: SiloConfig1

   **Status:** Reviewed manually

   **Severity:** Low

   Anything it returns should be immutable (no action against the config should change)

   

----

.. index:: SiloConfig2

.. describe:: SiloConfig2

   **Status:** NA

   **Severity:** High

   LTV configs (lt vs maxlt) are configured in a certain way

   maxlt is less than lt, probably less than 90% of lt. This property is required for other properties around the system, and is a configuration assumption

----

SiloFactory Properties
^^^^^^^^^^^^^^^^^^^^^^

.. index:: SiloFactory1

.. describe:: SiloFactory1

   **Status:** None

   **Severity:** Low

   Silo factory can only be initialized once

   

----

.. index:: SiloFactory2

.. describe:: SiloFactory2

   **Status:** None

   **Severity:** Med

   Silo factory can only be initialized by the msg.sender that created it

   (implying no front-run to the initialize() function is possible). Also TOB-SILO2-1

----

ShareCollateralToken Properties
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. index:: ShareCollateralToken1

.. describe:: ShareCollateralToken1

   **Status:** None

   **Severity:** High

   Collateral shares shouldn’t be sent if it makes the user liquidatable/insolvent (should be covered by the high level rule - 1)

   

----

InterestRateModel Properties
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. index:: InterestRateModel1

.. describe:: InterestRateModel1

   **Status:** None

   **Severity:** 

   Any call by a silo that returns some value, cannot be front-runnable by another silo (or any address) such that this call returns a different value
