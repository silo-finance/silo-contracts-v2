1. Update ve-silo/contracts/governance/SiloGovernor.sol:
    voting period to 10 minutes
2. Update ve-silo/deploy/MainnetBalancerMinterDeploy.s.sol:
    set MILO (0x8FfC46A1b7a3b12F4A11Db8877d302876DCA7Ab1) address instead of SILO
3. Update ve-silo/deploy/VotingEscrowDeploy.s.sol
    set MILO (0x8FfC46A1b7a3b12F4A11Db8877d302876DCA7Ab1) address instead of SILO
4. Update silo-core/deploy/SiloFactoryDeploy.s.sol:
    set daoFeeReceiver dev wallet address
    address devAddr = vm.addr(deployerPrivateKey);
    address daoFeeReceiver = devAddr;
5. Update ve-silo/deploy/FeeDistributorDeploy.s.sol:
    startTime to block.timestamp + 1 days
6. Update proposals/sip/sip-v2-init/SIPV2Init.sol:
    comment out feeDistributor.acceptOwnership()
    comment out uniswapSwapper.acceptOwnership()
7. Run anvil:
    ./ve-silo/test/milo-ccip-test/bash/local-tests/anvil-arbitrum.sh
    ./ve-silo/test/milo-ccip-test/bash/local-tests/anvil-optimism.sh
7. Run all steps from the ./run-all.sh
