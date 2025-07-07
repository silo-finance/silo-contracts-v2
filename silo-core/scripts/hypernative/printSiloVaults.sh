#!/usr/bin/env python3

"""
This script fetches and prints Silo vault addresses for a given chain key from the Silo Finance API.

Usage:
    python3 fetch_vault_addresses.py <chainKey>

Example:
    python3 fetch_vault_addresses.py ethereum

This script performs a POST request to:
    https://app.silo.finance/api/earn

It then extracts and prints only the "vaultAddress" values from the JSON response.
"""

import sys
import json
import requests
import re

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <chainKey>", file=sys.stderr)
        sys.exit(1)

    chain_key = sys.argv[1]

    url = "https://app.silo.finance/api/earn"
    headers = {
        "Content-Type": "application/json"
    }
    payload = {
        "search": None,
        "chainKeys": [chain_key],
        "type": "vault",
        "sort": None,
        "limit": 100,
        "offset": 0
    }

    try:
        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
        data = response.text
    except Exception as e:
        print(f"Error during request: {e}", file=sys.stderr)
        sys.exit(1)

    # Extract and print all vault addresses using regex (as in original script)
    matches = re.findall(r'"vaultAddress":"(0x[a-fA-F0-9]{40})"', data)
    for address in matches:
        print(address)

if __name__ == "__main__":
    main()
