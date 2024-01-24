definition depositSig() returns uint32 = sig:deposit(uint256,address).selector;
definition depositWithTypeSig() returns uint32 = sig:deposit(uint256,address,ISilo.AssetType).selector;
definition withdrawSig() returns uint32 = sig:withdraw(uint256,address,address).selector;
definition withdrawWithTypeSig() returns uint32 = sig:withdraw(uint256,address,address,ISilo.AssetType).selector;
definition mintSig() returns uint32 = sig:mint(uint256,address).selector;
definition mintWithTypeSig() returns uint32 = sig:mint(uint256,address,ISilo.AssetType).selector;
definition accrueInterestSig() returns uint32 = sig:accrueInterest().selector;
definition transitionCollateralSig() returns uint32 = sig:transitionCollateral(uint256,address,ISilo.AssetType).selector;
definition initalizeSig() returns uint32 = sig:initialize(address,address).selector;
