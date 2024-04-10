import "./SiloFunctionSig.spec";

function siloFnSelectorWithAssets(env e, method f, uint256 assetsOrShares) {
    address receiver;
    siloFnSelector_assets_receiver(e, f, assetsOrShares, receiver);
}

function siloFnSelectorWithReceiver(env e, method f, address receiver) {
    uint256 assetsOrShares;
    siloFnSelector_assets_receiver(e, f, assetsOrShares, receiver);
}

function siloFnSelector_assets_receiver(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) {
    address owner;
    ISilo.AssetType anyType;
    siloFnSelector(e, f, assetsOrShares, receiver, owner, anyType);
}

function siloFnSelector(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver,
    address owner,
    ISilo.AssetType anyType
) {
    if (f.selector == depositSig()) {
        deposit(e, assetsOrShares, receiver);
    } else if (f.selector == depositWithTypeSig()) {
        deposit(e, assetsOrShares, receiver, anyType);
    } else if (f.selector == flashLoanSig()) {
        address token;
        bytes data;
        flashLoan(e, receiver, token, assetsOrShares, data);
    } else if (f.selector == mintSig()) {
        mint(e, assetsOrShares, receiver);
    } else if (f.selector == mintWithTypeSig()) {
        mint(e, assetsOrShares, receiver, anyType);
    } else if (f.selector == borrowSig()) {
        // address anyBorrower = owner;
        borrow(e, assetsOrShares, receiver, owner);
    } else if (f.selector == borrowSharesSig()) {
        // address anyBorrower = owner;
        borrowShares(e, assetsOrShares, receiver, owner);
    } else if (f.selector == leverageSig()) {
        // address anyBorrower = owner;
        bytes data;
        require owner != currentContract;
        leverage(e, assetsOrShares, receiver, owner, data);
    } else if (f.selector == repaySig()) {
        // address anyBorrower = owner;
        require owner != currentContract;
        repay(e, assetsOrShares, owner);
    } else if (f.selector == repaySharesSig()) {
        // address anyBorrower = owner;
        require owner != currentContract;
        repayShares(e, assetsOrShares, owner);
    } else if (f.selector == transitionCollateralSig()) {
        transitionCollateral(e, assetsOrShares, receiver, anyType);
    } else if (f.selector == withdrawSig()) {
        withdraw(e, assetsOrShares, receiver, owner);
    } else if (f.selector == withdrawWithTypeSig()) {
        withdraw(e, assetsOrShares, receiver, owner, anyType);
    } else if(f.selector == redeemSig()) {
        redeem(e, assetsOrShares, receiver, owner);
    } else if(f.selector == redeemWithTypeSig()) {
        redeem(e, assetsOrShares, receiver, owner, anyType);
    } else if (f.selector == withdrawCollateralToLiquidatorSig()) {
        uint256 _withdrawAssetsFromCollateral;
        uint256 _withdrawAssetsFromProtected;
        
        address _borrower = owner;
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