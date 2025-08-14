#!/bin/bash

# Hypernative chain name (sonic) should be one of items from this list
# https://docs.hypernative.xyz/hypernative-product-docs/hypernative-web-application/supported-chains
# Usage: ./run_hypernative.sh <rpc_url> <hypernative_chain_alias> <deployments_dir>
# Usage: ./run_hypernative.sh $RPC_SONIC sonic sonic

set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <rpc_url> <hypernative_chain_alias> <deployments_dir>" >&2
    exit 1
fi

RPC_URL="$1"
HYPERNATIVE_CHAIN_ALIAS="$2"
DEPLOYMENTS_DIR="$3"

echo "Submitting silo-core and silo-vaults deployments..."

./silo-core/scripts/hypernative/printDeployments.sh $DEPLOYMENTS_DIR | \
    ./silo-core/scripts/hypernative/updateWatchlists.sh $HYPERNATIVE_CHAIN_ALIAS

echo "Submitting Silo addresses..."

FOUNDRY_PROFILE=core \
    forge script silo-core/scripts/PrintSiloAddresses.s.sol \
    --ffi --rpc-url $RPC_URL | \
    grep 0x | \
    ./silo-core/scripts/hypernative/updateWatchlists.sh $HYPERNATIVE_CHAIN_ALIAS

echo "Submitting SiloVault addresses..."

./silo-core/scripts/hypernative/printSiloVaults.sh $HYPERNATIVE_CHAIN_ALIAS | \
    ./silo-core/scripts/hypernative/updateWatchlists.sh $HYPERNATIVE_CHAIN_ALIAS
