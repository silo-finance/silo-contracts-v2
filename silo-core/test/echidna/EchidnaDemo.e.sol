// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

// SOLC_VERSION=0.8.21 echidna silo-core/test/echidna/EchidnaDemo.e.sol
contract EchidnaDemoTest {
    event Flag(bool);

    bool private flag0 = true;
    bool private flag1 = true;

    function set0(int val) public {
        if (val % 100 == 0)
            flag0 = false;
    }

    function set1(int val) public {
        if (val % 10 == 0 && !flag0)
            flag1 = false;
    }

    function echidna_alwaystrue() public returns (bool){
        return(true);
    }

    function echidna_revert_always() public returns (bool){
        revert();
    }

    function echidna_sometimesfalse() public returns (bool){
        emit Flag(flag0);
        emit Flag(flag1);
        return(flag1);
    }
}
