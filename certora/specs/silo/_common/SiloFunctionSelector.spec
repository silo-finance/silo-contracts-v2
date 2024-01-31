import "./SiloFunctionSig.spec";

function siloFnSelectorWithAssets(env e, method f, uint256 assets) {
    address receiver;
    siloFnSelector(e, f, assets, receiver);
}

function siloFnSelector(
    env e,
    method f,
    uint256 assets,
    address receiver
) {
    require e.block.timestamp < max_uint64;

    if (f.selector == depositSig()) {
        deposit(e, assets, receiver);
    } else if (f.selector == flashLoanSig()) {
        address token;
        bytes data;

        flashLoan(e, receiver, token, assets, data);
    } else {
        calldataarg args;
        f(e, args);
    }
}
