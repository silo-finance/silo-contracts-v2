#!/bin/bash

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <chainKey>" >&2
  exit 1
fi

CHAIN_KEY="$1"

# Fetch and extract vault addresses
curl -sS -X POST https://app.silo.finance/api/earn \
  -H "Content-Type: application/json" \
  -d '{
    "search": null,
    "chainKeys": ["'"$CHAIN_KEY"'"],
    "type": "vault",
    "sort": null,
    "limit": 100,
    "offset": 0
}' | grep -o '"vaultAddress":"0x[a-fA-F0-9]\{40\}"' | cut -d':' -f2 | tr -d '"'
