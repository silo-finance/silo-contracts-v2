definition depositSig() returns uint32 = sig:deposit(uint256,address).selector;
definition withdrawSig() returns uint32 = sig:withdraw(uint256,address,address).selector;
definition withdrawWithTypeSig() returns uint32 = sig:withdraw(uint256,address,address,ISilo.AssetType).selector;
definition mintSig() returns uint32 = sig:mint(uint256,address,ISilo.AssetType).selector;
definition accrueInterestSig() returns uint32 = sig:accrueInterest().selector;
