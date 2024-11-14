# Deploy ve-silo, silo-core, and oracles
./ve-silo/test/milo-ccip-test/bash/local-tests/arb-deployments.sh

# Send ETH to proposer
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Send Milo to proposer
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/SendMiloToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Transfer milo token ownership to balancer token admint
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/TransferMiloOwnership.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Approve Milo and get veSilo
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/ApproveAndGetVeSilo.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Increase time
# Send ETH to proposer (only to update block.timestamp)
cast rpc evm_increaseTime 600 --rpc-url http://127.0.0.1:8545 &&
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Run initial proposal
FOUNDRY_PROFILE=ve-silo-test \
    forge script proposals/sip/sip-v2-init/SIPV2Init.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Execute initial proposal
# Update PROPOSAL_ID
# ./ve-silo/test/milo-ccip-test/bash/local-tests/initial-proposal-execution.sh

# Deploy child chain (Optimism)
./ve-silo/test/milo-ccip-test/bash/local-tests/optimism-deployments.sh

# Create child chain gauge (Optimism)
FOUNDRY_PROFILE=ve-silo-test SHARE_TOKEN=0x64b08680f0F323514E588085c8D6b79c495b0135 \
    forge script ve-silo/test/milo-ccip-test/scripts/CreateChildChainGauge.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8546
# Configure child chain gauge (Optimism)
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xe15Df440e910bF05255a5da8AAEF254594fabE0e \
    GAUGE_HOOK=0xDC9653D5C27f1aba64B38Cd4aC6D332b689752eF \
    SHARE_TOKEN=0x64b08680f0F323514E588085c8D6b79c495b0135 \
    forge script ve-silo/test/milo-ccip-test/scripts/ConfigureGauge.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8546
# Check user details
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xe15Df440e910bF05255a5da8AAEF254594fabE0e \
    USER=0x6d228Fa4daD2163056A48Fc2186d716f5c65E89A \
    forge script ve-silo/test/milo-ccip-test/scripts/GetChildChainGaugeUser.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8546
# Deposit into the Silo and check user details again
FOUNDRY_PROFILE=ve-silo-test \
    SILO=0x64b08680f0F323514E588085c8D6b79c495b0135 \
    forge script ve-silo/test/milo-ccip-test/scripts/silo-helpers/SiloDeposit.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8546
# Increase time (8 days) and check user details again
# Send ETH to proposer (only to update block.timestamp)
cast rpc evm_increaseTime 691200 --rpc-url http://127.0.0.1:8546 &&
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8546


# Increase time
# Send ETH to proposer (only to update block.timestamp)
cast rpc evm_increaseTime 100 --rpc-url http://127.0.0.1:8545 &&
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Activate balancer token admin
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/proposals/activate-balancer-token-admin/ActivateBalancerTokenAdmin.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Execute activate balancer token admin proposal
# Update PROPOSAL_ID
./ve-silo/test/milo-ccip-test/proposals/activate-balancer-token-admin/_activation-proposal-execution.sh

# Increase time
# Send ETH to proposer (only to update block.timestamp)
cast rpc evm_increaseTime 100 --rpc-url http://127.0.0.1:8545 &&
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Create CCIP gauge Arbitrum
FOUNDRY_PROFILE=ve-silo-test \
    CHILD_CHAIN_GAUGE=0x6d504D8cd3d742674F900a9272564f24B57A10BC \
    forge script ve-silo/test/milo-ccip-test/scripts/CreateCCIPGaugeArbitrum.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Run gauge setup proposal (Arbitrum)
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xe26b060eB0aE73D93875840D0b44CA87884631d7 \
    forge script ve-silo/test/milo-ccip-test/proposals/gauge-setup/SIPV2CCIPGaugeSetUp.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Execute gauge setup proposal
# Update PROPOSAL_ID
# Update GAUGE
./ve-silo/test/milo-ccip-test/proposals/gauge-setup/_gauge-setup-proposal.sh

FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xe26b060eB0aE73D93875840D0b44CA87884631d7 \
    forge script ve-silo/test/milo-ccip-test/scripts/VoteForGauge.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Increase time (8 days)
# Send ETH to proposer (only to update block.timestamp)
cast rpc evm_increaseTime 691200 --rpc-url http://127.0.0.1:8545 &&
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Show claimable rewards
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xe26b060eB0aE73D93875840D0b44CA87884631d7 \
    forge script ve-silo/test/milo-ccip-test/scripts/ShowClaimableRewards.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Claim rewards
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xe26b060eB0aE73D93875840D0b44CA87884631d7 \
    forge script ve-silo/test/milo-ccip-test/scripts/ClaimMainChain.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545 -vvvv
# Execute stop mining proposal
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/proposals/end-incentives-program/StopMining.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Execute stop mining proposal
# Update PROPOSAL_ID
./ve-silo/test/milo-ccip-test/proposals/end-incentives-program/_stop-proposal-execution.sh
# Check components owners
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/PrintComponentsOwners.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545