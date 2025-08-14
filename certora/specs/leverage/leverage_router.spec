
/* Verification of LeverageRouter

In this verification we assume that clones library  (openzeppelin5/proxy/Clones.sol) has the following properties:
* predictDeterministicAddress return the same address as cloneDeterministic 
*


To run this file: certoraRun certora/config/silo/leverageRouter.conf  
result : https://prover.certora.com/output/40726/5ded49442eb744f48db2be31fdf4bcca/?anonymousKey=3ac339bd3d9c26dba41c4ac84c680239a332ef9

mutation test: https://mutation-testing.certora.com/?id=1d415263-90ff-446e-ab69-e5f6931d190c&anonymousKey=3e820d47-6591-4257-8cd1-4f328abfba9b
on mutants in certora/mutants/LeverageRouter and more

*/

methods {
    function userLeverageContract(address user) external returns address envfree;
    function predictUserLeverageContract(address _user) external returns address envfree;

    function _.predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal => deterministicAddress(salt) expect (address);

    function _.cloneDeterministic(
        address implementation,
        bytes32 salt
    ) internal => deterministicAddress(salt) expect (address);

    //calls to leverage are summarized to mark on behalf of which msgSender 
    function _.openLeveragePosition(address _msgSender,
            ILeverageUsingSiloFlashloan.FlashArgs _flashArgs,
            bytes _swapArgs,
            ILeverageUsingSiloFlashloan.DepositArgs _depositArgs) 
        external => markedCalled(_msgSender) expect void;

    function _.openLeveragePositionPermit(address _msgSender,
            ILeverageUsingSiloFlashloan.FlashArgs,
            bytes,
            ILeverageUsingSiloFlashloan.DepositArgs,
            ILeverageUsingSiloFlashloan.Permit)
        external => markedCalled(_msgSender) expect void;

    function _.closeLeveragePosition(address _msgSender,
            bytes,
            ILeverageUsingSiloFlashloan.CloseLeverageArgs) 
        external=> markedCalled(_msgSender) expect void;

    function _.closeLeveragePositionPermit(address _msgSender,
            bytes,
            ILeverageUsingSiloFlashloan.CloseLeverageArgs, 
            ILeverageUsingSiloFlashloan.Permit)
        external=> markedCalled(_msgSender) expect void;
    
}

ghost deterministicAddress(bytes32) returns address {
  axiom forall bytes32 b1. forall bytes32 b2.
  deterministicAddress(b1) == deterministicAddress(b2) => 
        (b1 == b2);
}

ghost address calledMsgSender;

function markedCalled(address x) {
    calledMsgSender = x;
}

/// @title Once a leverage contract is set for a user, it can not be changed
rule userLeverageContractImmutable(method f, address user) filtered {f -> !f.isView} {
    address beforeValue = userLeverageContract(user);

    env e;
    calldataarg args;
    f(e,args);

    assert beforeValue == 0 || beforeValue == userLeverageContract(user);
}

/// @title only the owner can use  his leverage
// this is proved by summarizing the calls to leverage and collecting the msgSender argument
rule calledWithMsgSender(method f) {
    require calledMsgSender == 0;
    env e;
    calldataarg args;
    f(e,args);
    assert calledMsgSender == 0 || calledMsgSender == e.msg.sender;
}


// uniqueness of leverageContract 
rule uniqueness(address user1, address user2) {
    require user1 != 0 && user2 != 0; 
    require currentContract.LEVERAGE_IMPLEMENTATION != 0;
    address contractUser1 = predictUserLeverageContract(user1); 
    address contractUser2 = predictUserLeverageContract(user2);
    assert contractUser1  == contractUser2 => ( user1 == user2 || contractUser1 == 0); 
}

// predictUserLeverageContract should not revert
rule predictRevert(address user) {
    predictUserLeverageContract@withrevert(user);
    assert !lastReverted;
}

// predictUserLeverageContract vs the actual userLeverageContract address
// this is based on assuming that in the clone library predictDeterministicAddress return the same address as cloneDeterministic
rule predictIntegrity(address user, method f) {
    require userLeverageContract(user) == 0 || predictUserLeverageContract(user) == userLeverageContract(user);
    env e;
    calldataarg args;
    f(e,args);
    assert userLeverageContract(user) == 0 || predictUserLeverageContract(user) == userLeverageContract(user);
}
