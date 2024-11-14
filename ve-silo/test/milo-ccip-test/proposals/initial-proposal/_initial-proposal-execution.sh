# Increase time
cast rpc evm_increaseTime 2 --rpc-url http://127.0.0.1:8545
# Send ETH to proposer (only to update block.timestamp)
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Cast vote (Proposal Id needs to be updated)
FOUNDRY_PROFILE=ve-silo-test \
    PROPOSAL_ID=42548144802583640354581599602433438946835174767948355966385744251745861597226 \
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
    forge script ve-silo/test/milo-ccip-test/proposals/initial-proposal/QueueInitProposal.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Increase time for timelock.getMinDelay() == 1
cast rpc evm_increaseTime 2 --rpc-url http://127.0.0.1:8545
# Send ETH to proposer (only to update block.timestamp)
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

# Execute proposal
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/proposals/initial-proposal/ExecuteInitProposal.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
