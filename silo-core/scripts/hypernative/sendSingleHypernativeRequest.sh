#!/usr/bin/env python3

"""
This script reads Ethereum addresses from stdin and adds them to an existing Hypernative monitor.

Environment variables required:
- HYPERNATIVE_WATCHLIST: The full PATCH API URL of the watchlist endpoint.
- HYPERNATIVE_CLIENT_ID: Your Hypernative client ID.
- HYPERNATIVE_CLIENT_SECRET: Your Hypernative client secret.

Usage:
    python3 hypernative_submit.py <chain-name>

Example integration:
    The chain name (e.g., 'sonic') must be one of the supported chains:
    https://docs.hypernative.xyz/hypernative-product-docs/hypernative-web-application/supported-chains

    Example command that pipes addresses to this script:
        FOUNDRY_PROFILE=core \
        forge script silo-core/scripts/PrintSiloAddresses.s.sol \
        --ffi --rpc-url $RPC_SONIC | grep 0x | python3 hypernative_submit.py sonic
"""

import sys
import os
import json
import requests

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <chain-name>")
        sys.exit(1)

    chain_name = sys.argv[1]
    addresses = []

    # Read addresses from stdin
    for line in sys.stdin:
        address = line.strip()
        if address:
            addresses.append(address)

    if not addresses:
        print("No addresses provided on stdin.")
        sys.exit(1)

    print(f"Amount of addresses to submit is {len(addresses)}")

    # Build assets JSON array
    assets = [{
        "chain": chain_name,
        "type": "Contract",
        "address": addr
    } for addr in addresses]

    payload = {
        "name": "All Silo0 and Silo1 addresses",
        "description": "",
        "assets": assets,
        "mode": "add"
    }

    url = os.getenv("HYPERNATIVE_WATCHLIST")
    client_id = os.getenv("HYPERNATIVE_CLIENT_ID")
    client_secret = os.getenv("HYPERNATIVE_CLIENT_SECRET")

    if not url or not client_id or not client_secret:
        print("Error: HYPERNATIVE_WATCHLIST, HYPERNATIVE_CLIENT_ID, or HYPERNATIVE_CLIENT_SECRET not set.", file=sys.stderr)
        sys.exit(1)

    headers = {
        "accept": "application/json",
        "Content-Type": "application/json",
        "x-client-id": client_id,
        "x-client-secret": client_secret,
    }

    try:
        response = requests.patch(url, headers=headers, json=payload)
        response.raise_for_status()
        result = response.json()
    except Exception as e:
        print(f"Error: PATCH failed - {e}", file=sys.stderr)
        sys.exit(1)

    if result.get("success") is True:
        print(f"Success from Hypernative response for {chain_name}")
        sys.exit(0)
    else:
        print("Error: PATCH failed or did not return \"success\": true in response", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
