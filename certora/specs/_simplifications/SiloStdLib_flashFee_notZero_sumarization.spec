methods {
    function SiloStdLib.flashFee() internal returns (uint256) => accrueInterest_noStateChange();
}


function cflashFee_notZero() returns uint256 {
    uint256 fee;
    
    require fee > 0;

    return fee;
}
