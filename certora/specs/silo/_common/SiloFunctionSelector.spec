import "./SiloFunctionSig.spec";

function siloFnSelectorWithAssets(env e, method f, uint256 assetsOrShares) {
    address receiver;
    siloFnSelector(e, f, assetsOrShares, receiver);
}

function siloFnSelector(
    env e,
    method f,
    uint256 assetsOrShares,
    address receiver
) {
    require e.block.timestamp < max_uint64;
    require e.msg.sender != silo0;
    require receiver != silo0;

    if (f.selector == depositSig()) {
        require receiver != currentContract;
        deposit(e, assetsOrShares, receiver);
    } else if (f.selector == depositWithTypeSig()) {
        require receiver != currentContract;
        ISilo.AssetType anyType;
        deposit(e, assetsOrShares, receiver, anyType);
    } else if (f.selector == flashLoanSig()) {
        address token;
        bytes data;

        flashLoan(e, receiver, token, assetsOrShares, data);
    } else if (f.selector == mintSig()) {
        require receiver != currentContract;
        mint(e, assetsOrShares, receiver);
    } else if (f.selector == mintWithTypeSig()) {
        require receiver != currentContract;
        ISilo.AssetType anyType;
        mint(e, assetsOrShares, receiver, anyType);
    } else {
        calldataarg args;
        f(e, args);
    }
}
