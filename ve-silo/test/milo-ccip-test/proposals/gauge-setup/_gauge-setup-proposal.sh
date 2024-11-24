# Increase time
cast rpc evm_increaseTime 2 --rpc-url http://127.0.0.1:8545
# Send ETH to proposer (only to update block.timestamp)
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Cast vote (Proposal Id needs to be updated)
FOUNDRY_PROFILE=ve-silo-test \
    PROPOSAL_ID=108724651736310025786993210385484418999592755148694666466951357105417503006107 \
    forge script ve-silo/test/milo-ccip-test/scripts/CastVote.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Increase time (move after deadline)
cast rpc evm_increaseTime 2070 --rpc-url http://127.0.0.1:8545
# # Send ETH to proposer (only to update block.timestamp)
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Queue proposal
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xe26b060eB0aE73D93875840D0b44CA87884631d7 \
    forge script ve-silo/test/milo-ccip-test/proposals/gauge-setup/QueueCCIPGaugeSetUp.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Increase time for timelock.getMinDelay() == 1
cast rpc evm_increaseTime 2 --rpc-url http://127.0.0.1:8545
# Send ETH to proposer (only to update block.timestamp)
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Execute proposal
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xe26b060eB0aE73D93875840D0b44CA87884631d7 \
    forge script ve-silo/test/milo-ccip-test/proposals/gauge-setup/ExecuteCCIPGaugeSetUpProposal.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
