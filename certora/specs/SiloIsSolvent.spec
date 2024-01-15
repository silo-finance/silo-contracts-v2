
methods {
    /// functions that are not dependent on the enviroment
    function isSolvent(address) external returns(bool) envfree;
}

// certoraRun certora/confs/silo-core/silo_isSolvent.conf
rule userCanNotPutHimselfIntoInsolvency(method f, address borrower) filtered { f -> !f.isView } {
    // address borrower;

    env e;

    require currentContract.isSolvent(borrower);
    // silo has super powers, but do we need to limit?
    require e.msg.sender != currentContract;

    calldataarg args;
    f(e, args);

    // whatever happen user must stay solvent
    assert currentContract.isSolvent(borrower);
}
