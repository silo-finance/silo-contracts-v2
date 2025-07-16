#!/usr/bin/env bash

# Usage: ./towerRegistration.sh [--broadcast]

# Array of environment variable names
rpc_envs=("RPC_ARBITRUM" "RPC_AVALANCHE" "RPC_INK" "RPC_MAINNET" "RPC_OPTIMISM" "RPC_SONIC")

# Set common profile and script path
export FOUNDRY_PROFILE=core
script_path="silo-core/deploy/TowerRegistration.s.sol:TowerRegistration"

# Check for --broadcast flag
broadcast_flag=""
if [[ "$1" == "--broadcast" ]]; then
    broadcast_flag="--broadcast"
fi

for rpc_env in "${rpc_envs[@]}"; do
    rpc_url="${!rpc_env}"

    if [[ -z "$rpc_url" ]]; then
        echo "⚠️  Environment variable $rpc_env is not set. Skipping."
        continue
    fi

    echo "🚀 Executing script on ${rpc_env}..."
    forge script "$script_path" \
        --ffi \
        --rpc-url "$rpc_url" \
        $broadcast_flag
done
