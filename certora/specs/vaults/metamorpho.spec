

rule sanity(env e, method f) {
    calldataarg arg;
    f(e, arg);
    satisfy(true);
}
