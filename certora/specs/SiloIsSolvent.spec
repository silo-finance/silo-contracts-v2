
methods {
    /// functions that are not dependent on the enviroment
    function isSolvent(address) external returns(bool) envfree;
}

// certoraRun certora/confs/silo-core/silo_isSolvent.conf
rule userCanNotPutHimselfIntoInsolvency(method f, address borrower) filtered { f -> !f.isView } {
    // address borrower;

    env e;

    ISiloConfig siloConfig = currentContract.config();
    ISiloConfig.ConfigData cfg = siloConfig.getConfig();

    require cfg.solvencyOracle == 0x0;
    require cfg.maxLtvOracle == 0x0;


    require currentContract.isSolvent(borrower);
    // silo has super powers, but do we need to limit?
    require e.msg.sender != currentContract;

    calldataarg args;
    f(e, args);

    // whatever happen user must stay solvent
    assert currentContract.isSolvent(borrower);
}
