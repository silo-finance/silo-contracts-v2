import "./SiloFunctionSig.spec";

function siloFnSelectorWithAmount(env e, method f, uint256 amount) {
    address receiver;
    siloFnSelector(e, f, amount, receiver);
}

function siloFnSelector(
    env e,
    method f,
    uint256 amount,
    address receiver
) {
    require e.block.timestamp < max_uint64;
    require amount > 1;

    if (f.selector == depositSig()) {
        deposit(e, amount, receiver);
    } else {
        calldataarg args;
        f(e, args);
    }
}
