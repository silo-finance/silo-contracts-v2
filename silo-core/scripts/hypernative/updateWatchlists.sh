#!/bin/bash

# This script reads addresses from stdin and adds these addresses to existing Hypernative monitor.
# HYPERNATIVE_WATCHLIST, HYPERNATIVE_CLIENT_ID and HYPERNATIVE_CLIENT_SECRET must be set.

# Usage example:
# Chain name (sonic) should be one of items from this list
# https://docs.hypernative.xyz/hypernative-product-docs/hypernative-web-application/supported-chains
# FOUNDRY_PROFILE=core \
#    forge script silo-core/scripts/PrintSiloAddresses.s.sol \
#    --ffi --rpc-url $RPC_SONIC | grep 0x | ./silo-core/scripts/hypernative.sh sonic

if [ $# -ne 1 ]; then
    echo "Usage: $0 <chain-name>" >&2
    exit 1
fi

CHAIN_NAME="$1"
ADDRESSES=()

# Read addresses from stdin
while read -r address; do
    [[ -z "$address" ]] && continue
    ADDRESSES+=("$address")
done

# Build the JSON payload dynamically
JSON_ASSETS=""
for ((i = 0; i < ${#ADDRESSES[@]}; i++)); do
    ADDR="${ADDRESSES[$i]}"
    COMMA=","
    [[ $i -eq $((${#ADDRESSES[@]} - 1)) ]] && COMMA=""
    JSON_ASSETS+="
        {
        \"chain\": \"${CHAIN_NAME}\",
        \"type\": \"Contract\",
        \"address\": \"${ADDR}\"
        }${COMMA}"
done

echo "Amount of addresses to submit is ${#ADDRESSES[@]}"

for WATCHLIST_TYPE in "pause" "sandbox"; do
    echo "Sending request to update ${WATCHLIST_TYPE} watchlist..."

    if [ "$WATCHLIST_TYPE" = "pause" ]; then
        URL="$HYPERNATIVE_WATCHLIST_PAUSE"
    else
        URL="$HYPERNATIVE_WATCHLIST_SANDBOX"
    fi

    RESPONSE=$(curl -X 'PATCH' \
        "$URL" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        -H "x-client-id: $HYPERNATIVE_CLIENT_ID" \
        -H "x-client-secret: $HYPERNATIVE_CLIENT_SECRET" \
        -d '{
        "description": "",
        "assets": [
        '"$JSON_ASSETS"'
        ],
        "mode": "add"
    }' 2>/dev/null)

    if echo "$RESPONSE" | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
        echo "Success from Hypernative ${WATCHLIST_TYPE} watchlist update response for $CHAIN_NAME"
    else
        echo "Error: Hypernative ${WATCHLIST_TYPE} watchlist update did not return \"success\":true in response" >&2
        exit 1
    fi
done
