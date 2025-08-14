#!/bin/bash

# Usage ./silo-core/scripts/hypernative/printDeployments.sh sonic

# Check for required folder argument
if [ -z "$1" ]; then
    echo "Usage: $0 <folder-name>" >&2
    exit 1
fi

CORE_DEPLOYMENTS_DIR="silo-core/deployments/$1"
VAULTS_DEPLOYMENTS_DIR="silo-vaults/deployments/$1"

DIRS_ARRAY=("$CORE_DEPLOYMENTS_DIR" "$VAULTS_DEPLOYMENTS_DIR")

for dir in "${DIRS_ARRAY[@]}"; do
    # Verify the directory exists
    if [ ! -d "$dir" ]; then
        echo "Directory not found: $dir" >&2
        exit 1
    fi

    # Iterate over JSON files and extract address values
    for file in "$dir"/*.json; do
        grep -m 1 '"address":' "$file" | cut -d '"' -f4
    done
done
