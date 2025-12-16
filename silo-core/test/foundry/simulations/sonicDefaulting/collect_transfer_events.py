#!/usr/bin/env python3
"""
Script to collect IERC20.Transfer events from a Silo contract.
Usage: python collect_transfer_events.py <contract_address>
"""

import sys
import json
import os
from web3 import Web3
from eth_abi import encode
from eth_utils import to_hex

# Hardcoded RPC URL
RPC_URL = "https://sonic-mainnet.g.alchemy.com/v2/aNrPwztzUMrRelRP2OkYVAQc0CHo4DJk"  # Update this to your actual RPC URL

# Output JSON file
OUTPUT_FILE = "events.json"

# ERC20 Transfer event signature
TRANSFER_EVENT_SIGNATURE = "Transfer(address,address,uint256)"


def load_existing_events():
    """Load existing events from JSON file if it exists."""
    if os.path.exists(OUTPUT_FILE):
        with open(OUTPUT_FILE, 'r') as f:
            return json.load(f)
    return {}


def save_events(events_dict):
    """Save events to JSON file, sorted by block number and transaction index."""
    # Sort events by block number, then by transaction index
    sorted_events = dict(sorted(
        events_dict.items(),
        key=lambda x: (x[1]['blockNumber'], x[1]['txOrder'])
    ))
    
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(sorted_events, f, indent=2)


def encode_event_args(event_args):
    """
    Encode event arguments as bytes for Solidity abi.decode.
    Transfer event: (address from, address to, uint256 value)
    """
    from_addr = event_args['from']
    to_addr = event_args['to']
    value = event_args['value']
    
    # Encode as (address, address, uint256)
    encoded = encode(['address', 'address', 'uint256'], [from_addr, to_addr, value])
    return to_hex(encoded)


def collect_transfer_events(contract_address):
    """Collect Transfer events from the contract."""
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    
    if not w3.is_connected():
        print(f"Error: Could not connect to RPC at {RPC_URL}")
        sys.exit(1)
    
    # Load existing events
    existing_events = load_existing_events()
    existing_keys = set(existing_events.keys())
    
    # Create event filter
    event_signature_hash = w3.keccak(text=TRANSFER_EVENT_SIGNATURE)
    
    # Get Transfer events from the contract
    # We'll query from block 0 to latest, but you might want to limit this
    print(f"Querying Transfer events from contract {contract_address}...")
    
    # Create filter for Transfer events
    transfer_filter = w3.eth.filter({
        'fromBlock': 5773890,
        'toBlock': 'latest',
        'address': contract_address,
        'topics': [event_signature_hash]
    })
    
    events = transfer_filter.get_all_entries()
    print(f"Found {len(events)} Transfer events")
    
    new_events_count = 0
    
    for event in events:
        tx_hash = event['transactionHash'].hex()
        
        # Use tx_hash as the key (as per user requirement)
        # If transaction already exists, skip it
        if tx_hash in existing_keys:
            continue
        
        # Get transaction details
        tx = w3.eth.get_transaction(tx_hash)
        tx_receipt = w3.eth.get_transaction_receipt(tx_hash)
        block = w3.eth.get_block(tx_receipt['blockNumber'])
        
        # Decode event arguments
        # Transfer(address indexed from, address indexed to, uint256 value)
        # Topics: [event_signature, from, to]
        # Data: value (uint256)
        from_addr = '0x' + event['topics'][1].hex()[26:]  # Remove padding
        to_addr = '0x' + event['topics'][2].hex()[26:]     # Remove padding
        
        # Handle data field (value as uint256)
        data_hex = event['data'].hex() if hasattr(event['data'], 'hex') else event['data']
        if isinstance(data_hex, str) and data_hex.startswith('0x'):
            value = int(data_hex, 16)
        else:
            value = int(data_hex, 16) if isinstance(data_hex, str) else int.from_bytes(event['data'], 'big')
        
        event_args = {
            'from': from_addr,
            'to': to_addr,
            'value': value
        }
        
        # Encode event arguments as bytes
        encoded_args = encode_event_args(event_args)
        
        # Create event entry
        event_entry = {
            'timestamp': block['timestamp'],
            'blockNumber': tx_receipt['blockNumber'],
            'txOrder': tx_receipt['transactionIndex'],
            'txHash': tx_hash,
            'txFrom': tx['from'],
            'txTo': tx['to'] if tx['to'] else None,  # Handle contract creation
            'eventName': 'Transfer',
            'eventArgs': encoded_args
        }
        
        existing_events[tx_hash] = event_entry
        new_events_count += 1
    
    if new_events_count > 0:
        print(f"Added {new_events_count} new Transfer events")
        save_events(existing_events)
    else:
        print("No new Transfer events found")
    
    print(f"Total events in file: {len(existing_events)}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python collect_transfer_events.py <contract_address>")
        sys.exit(1)
    
    contract_address = sys.argv[1]
    
    # Validate address
    if not Web3.is_address(contract_address):
        print(f"Error: Invalid contract address: {contract_address}")
        sys.exit(1)
    
    # Normalize address (checksum)
    contract_address = Web3.to_checksum_address(contract_address)
    
    collect_transfer_events(contract_address)

