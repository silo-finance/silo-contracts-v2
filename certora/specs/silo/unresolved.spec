// let's add dispatchers here if we see unreaolsved calls
// we can later put it somehwere else

import "../requirements/two_silos_methods.spec";

methods {
    function _.reentrancyGuardEntered() external => DISPATCHER(true);
    function _.synchronizeHooks(uint24,uint24) external => NONDET;
}