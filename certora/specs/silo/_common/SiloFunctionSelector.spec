import "./SiloFunctionSig.spec";

function siloFnSelectorWithAssets(env e, method f, uint256 assets) {
    address receiver;
    siloFnSelector(e, f, assets, receiver);
}

function siloFnSelector(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) {
    require e.block.timestamp < max_uint64;

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
    } else {
        calldataarg args;
        f(e, args);
    }
}
