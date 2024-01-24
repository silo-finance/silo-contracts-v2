import "./SiloFunctionSig.spec";
import "./SiloConfigMethods.spec";

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
    } else if (f.selector == initalizeSig()) {
        address anyModel;
        initialize(e, siloConfig, anyModel);
    } else {
        calldataarg args;
        f(e, args);
    }
}
