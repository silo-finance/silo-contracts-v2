FIRM.accrueInterest() returns (interest)
  if (lastUpdateTimestamp == block.timestamp) return 0;

  totalInterestToDistribute = ShareCollateralToken.balanceOf(address(this));

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

  ShareCollateralToken.transfer(FIRMVault, interest);


FIRM.getCurrentInterestRate() returns (rcur)
       rcur = block.timestamp < maturityDate ? APR : 0; // Borrower


FIRM.getCurrentInterestRateDepositor() returns (rcur)
  sharesBalance = ShareCollateralToken.balanceOf(FIRMVault);
  totalInterestToDistribute = ShareCollateralToken.balanceOf(address(this));

  distributeTillTime = block.timestamp >= maturityDate ? block.timestamp : maturityDate;
  interestTimeDelta = distributeTillTime - lastUpdateTimestamp;

  rcur = totalInterestToDistribute * 10**18 * 365 days / (sharesBalance * interestTimeDelta);
  rcur = Math.min(rcur, 10_000%);


FIRM.capInterest(interest) returns (cappedInterest) {
  cap = block.timestamp < maturityDate ? APR : 100; // 100 is 10_000%
  sharesBalance = ShareCollateralToken.balanceOf(FIRMVault);
  interestTimeDelta = block.timestamp - lastUpdateTimestamp;

  maxInterest = cap * sharesBalance * interestTimeDelta / 365 days;

  cappedInterest = Math.min(interest, maxInterest);
}


FIRM.accrueInterestView() returns (interest);