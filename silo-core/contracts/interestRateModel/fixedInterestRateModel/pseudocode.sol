FIRM.increaseTotalInterest(collateralShares) // protected only silo hook
   accrueInterest();
   totalInterestToDistribute += collateralShares;


FIRM.accrueInterest() returns (interest)
  if (lastUpdateTimestamp == block.timestamp) return 0;

  if (totalInterestToDistribute == 0) {
      lastUpdateTimestamp = block.timestamp;
      return 0;
  }

  if (block.timestamp >= maturityDate)
      interest = totalInterestToDistribute;
  else
     accruedInterestTimeDelta = block.timestamp - lastUpdateTimestamp;
     interestTimeDelta = maturityDate - lastUpdateTimestamp;
     interest = totalInterestToDistribute * accruedInterestTimeDelta / interestTimeDelta;

  interest = FIRM.capInterest(interest);
  lastUpdateTimestamp = block.timestamp; // update a state

  if (interest == 0) return 0;

  totalInterestToDistribute -= interest; // update a state
  ShareCollateralToken.transfer(FIRMVault, interest);


FIRM.getCurrentInterestRate() returns (rcur)
       rcur = block.timestamp < maturityDate ? APR : 0; // Borrower


FIRM.getCurrentInterestRateDepositor() returns (rcur)
  sharesBalance = ShareCollateralToken.balanceOf(FIRMVault);

  distributeTillTime = block.timestamp >= maturityDate ? block.timestamp : maturityDate;
  interestTimeDelta = distributeTillTime - lastUpdateTimestamp;

  rcur = totalInterestToDistribute * 10**18 * 365 days / (sharesBalance * interestTimeDelta);
  rcur = Math.min(rcur, 10_000%);


FIRM.capInterest(interest) returns (cappedInterest) {
  sharesBalance = ShareCollateralToken.balanceOf(FIRMVault);
  interestTimeDelta = block.timestamp - lastUpdateTimestamp;

  // 100 is 10_000%
  maxInterest = 100 * sharesBalance * interestTimeDelta / 365 days;

  cappedInterest = Math.min(interest, maxInterest);
}


FIRM.accrueInterestView() returns (interest);