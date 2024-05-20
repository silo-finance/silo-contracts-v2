# Deploy ve-silo
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/MainnetWithMocksDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Deploy silo-core
FOUNDRY_PROFILE=core \
    forge script silo-core/deploy/MainnetDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Send ETH to proposer
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Transfer silo token ownership to balancer token admint
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/TransferSiloMockOwnership.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Approve BPT and get veSilo
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/ApproveAndGetVeSilo.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Increase time
cast rpc evm_increaseTime 7200 --rpc-url http://127.0.0.1:8545
# Send ETH to proposer (only to update block.timestamp)
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Run initial proposal
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/proposals/SIPV2InitWithMocks.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Increase time
cast rpc evm_increaseTime 2 --rpc-url http://127.0.0.1:8545
# Send ETH to proposer (only to update block.timestamp)
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
# Cast vote (Proposal Id needs to be updated)
# FOUNDRY_PROFILE=ve-silo-test \
#     PROPOSAL_ID=89423994311314790873556818282176079585245375259584232113799305170808348158717 \
#     forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/CastVote.sol \
#     --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Increase time (move after deadline)
# cast rpc evm_increaseTime 2070 --rpc-url http://127.0.0.1:8545
# # Send ETH to proposer (only to update block.timestamp)
# FOUNDRY_PROFILE=ve-silo-test \
#     forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/SendEthToProposer.sol \
#     --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Queue proposal
# FOUNDRY_PROFILE=ve-silo-test \
#     forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/QueueInitWithMocksProposal.sol \
#     --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Increase time for timelock.getMinDelay() == 1
# cast rpc evm_increaseTime 2 --rpc-url http://127.0.0.1:8545
# # Send ETH to proposer (only to update block.timestamp)
# FOUNDRY_PROFILE=ve-silo-test \
#     forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/SendEthToProposer.sol \
#     --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Execute proposal
# FOUNDRY_PROFILE=ve-silo-test \
#     forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/ExecuteInitWithMocksProposal.sol \
#     --ffi --broadcast --rpc-url http://127.0.0.1:8545