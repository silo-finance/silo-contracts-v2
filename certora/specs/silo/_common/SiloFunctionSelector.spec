import "./SiloFunctionSig.spec";

function siloFnSelectorWithAssets(env e, method f, uint256 assetsOrShares) {
    address receiver;
    siloFnSelector(e, f, assetsOrShares, receiver);
}

function siloFnSelectorWithReceiver(env e, method f, address receiver) {
    uint256 assetsOrShares;
    siloFnSelector(e, f, assetsOrShares, receiver);
}

function siloFnSelector(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) {
    if (f.selector == depositSig()) {
        deposit(e, assetsOrShares, receiver);
    } else if (f.selector == depositWithTypeSig()) {
        ISilo.AssetType anyType;
        deposit(e, assetsOrShares, receiver, anyType);
    } else if (f.selector == flashLoanSig()) {
        address token;
        bytes data;
        flashLoan(e, receiver, token, assetsOrShares, data);
    } else if (f.selector == mintSig()) {
        mint(e, assetsOrShares, receiver);
    } else if (f.selector == mintWithTypeSig()) {
        ISilo.AssetType anyType;
        mint(e, assetsOrShares, receiver, anyType);
    } else if (f.selector == borrowSig()) {
        address anyBorrower;
        borrow(e, assetsOrShares, receiver, anyBorrower);
    } else if (f.selector == borrowSharesSig()) {
        address anyBorrower;
        borrowShares(e, assetsOrShares, receiver, anyBorrower);
    } else if (f.selector == leverageSig()) {
        address anyBorrower;
        bytes data;
        require anyBorrower != currentContract;
        leverage(e, assetsOrShares, receiver, anyBorrower, data);
    } else if (f.selector == repaySig()) {
        address anyBorrower;
        require anyBorrower != currentContract;
        repay(e, assetsOrShares, anyBorrower);
    } else if (f.selector == repaySharesSig()) {
        address anyBorrower;
        require anyBorrower != currentContract;
        repayShares(e, assetsOrShares, anyBorrower);
    } else if (f.selector == transitionCollateralSig()) {
        ISilo.AssetType anyType;
        transitionCollateral(e, assetsOrShares, receiver, anyType);
    } else if (f.selector == withdrawSig()) {
        address owner;
        withdraw(e, assetsOrShares, receiver, owner);
    } else if (f.selector == withdrawWithTypeSig()) {
        address owner;
        ISilo.AssetType anyType;
        withdraw(e, assetsOrShares, receiver, owner, anyType);
    } else if(f.selector == redeemSig()) {
        address owner;
        redeem(e, assetsOrShares, receiver, owner);
    } else if(f.selector == redeemWithTypeSig()) {
        address owner;
        ISilo.AssetType anyType;
        redeem(e, assetsOrShares, receiver, owner, anyType);
    } else if (f.selector == withdrawCollateralToLiquidatorSig()) {
        uint256 _withdrawAssetsFromCollateral;
        uint256 _withdrawAssetsFromProtected;
        
        address _borrower;
        address _liquidator;
        bool _receiveSToken;
         
        require receiver == _liquidator;
        require assetsOrShares == require_uint256(_withdrawAssetsFromCollateral + _withdrawAssetsFromProtected);
       
        withdrawCollateralsToLiquidator(
            e,
            _withdrawAssetsFromCollateral,
            _withdrawAssetsFromProtected,
            _borrower,
            _liquidator,
            _receiveSToken
        );
    }
    else {
        calldataarg args;
        f(e, args);
    }
}