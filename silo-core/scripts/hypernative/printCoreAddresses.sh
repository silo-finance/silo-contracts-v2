#!/bin/bash

# Usage ./silo-core/scripts/hypernative/printCoreAddresses.sh sonic

# Check for required folder argument
if [ -z "$1" ]; then
    echo "Usage: $0 <folder-name>" >&2
    exit 1
fi

DEPLOYMENTS_DIR="silo-core/deployments/$1"

# Verify the directory exists
if [ ! -d "$DEPLOYMENTS_DIR" ]; then
    echo "Directory not found: $DEPLOYMENTS_DIR" >&2
    exit 1
fi

# Iterate over JSON files and extract address values
for file in "$DEPLOYMENTS_DIR"/*.json; do
    grep -m 1 '"address":' "$file" | cut -d '"' -f4
done
