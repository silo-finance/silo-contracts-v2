#!/usr/bin/env python3
"""
Script to collect IERC20.Transfer events from a Silo contract.


silo0:
python3 silo-core/test/foundry/simulations/sonicDefaulting/collect_transfer_events.py 0xf55902DE87Bd80c6a35614b48d7f8B612a083C12
protected0:
python3 silo-core/test/foundry/simulations/sonicDefaulting/collect_transfer_events.py 0xAecD6cBf567AE7dE05f7E32eB051525e9fcd9bc6
debt0:
python3 silo-core/test/foundry/simulations/sonicDefaulting/collect_transfer_events.py 0xE5c066B23c7A97899646b0bbe69f3E8bc4b61C1C

silo1:
python3 silo-core/test/foundry/simulations/sonicDefaulting/collect_transfer_events.py 0x322e1d5384aa4ED66AeCa770B95686271de61dc3
protected1:
python3 silo-core/test/foundry/simulations/sonicDefaulting/collect_transfer_events.py 0x0B960e953649269B4c895C593108fBc7F8b61a24
debt1:
python3 silo-core/test/foundry/simulations/sonicDefaulting/collect_transfer_events.py 0xbc4eF1B5453672a98073fbFF216966F5039ad256
"""

import sys
import json
import os
from pathlib import Path
from web3 import Web3
from eth_abi import encode
from eth_utils import to_hex

# Hardcoded RPC URL
RPC_URL = "https://sonic-mainnet.g.alchemy.com/v2/aNrPwztzUMrRelRP2OkYVAQc0CHo4DJk"  # Update this to your actual RPC URL

# Hardcoded block range
FROM_BLOCK = 58061678
TO_BLOCK = 58061678  # Use 'latest' for latest block, or specific block number

# Output JSON file - save in the same directory as this script
SCRIPT_DIR = Path(__file__).parent.absolute()
OUTPUT_FILE = str(SCRIPT_DIR / "events.json")

# ERC20 Transfer event signature
TRANSFER_EVENT_SIGNATURE = "Transfer(address,address,uint256)"


def load_existing_events():
    """Load existing events from JSON file if it exists."""
    if os.path.exists(OUTPUT_FILE):
        with open(OUTPUT_FILE, 'r') as f:
            events = json.load(f)
            # Normalize keys to always have 0x prefix and convert to array format
            normalized_events = {}
            for key, value in events.items():
                normalized_key = key if key.startswith('0x') else '0x' + key
                
                # Convert old format (single event) to new format (array of events)
                if isinstance(value, dict):
                    # Old format: single event object
                    if 'txHash' in value and not value['txHash'].startswith('0x'):
                        value['txHash'] = '0x' + value['txHash']
                    normalized_events[normalized_key] = [value]
                elif isinstance(value, list):
                    # New format: array of events
                    for event in value:
                        if 'txHash' in event and not event['txHash'].startswith('0x'):
                            event['txHash'] = '0x' + event['txHash']
                    normalized_events[normalized_key] = value
            return normalized_events
    return {}


def save_events(events_dict):
    """Save events to JSON file, sorted by block number and transaction index."""
    # Sort events by block number, then by transaction index
    # For arrays, use the first event's blockNumber and txOrder
    sorted_events = dict(sorted(
        events_dict.items(),
        key=lambda x: (x[1][0]['blockNumber'], x[1][0]['txOrder']) if x[1] else (0, 0)
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
    
    # Create event filter
    event_signature_hash = w3.keccak(text=TRANSFER_EVENT_SIGNATURE)
    
    # Get Transfer events from the contract
    # We'll query from block 0 to latest, but you might want to limit this
    print(f"Querying Transfer events from contract {contract_address}...")
    
    # Create filter for Transfer events
    transfer_filter = w3.eth.filter({
        'fromBlock': FROM_BLOCK,
        'toBlock': TO_BLOCK,
        'address': contract_address,
        'topics': [event_signature_hash]
    })
    
    events = transfer_filter.get_all_entries()
    print(f"Found {len(events)} Transfer events")
    
    new_events_count = 0
    # Cache transaction details to avoid redundant RPC calls
    tx_cache = {}
    
    for event in events:
        tx_hash_raw = event['transactionHash'].hex()
        # Ensure tx_hash has 0x prefix
        tx_hash = tx_hash_raw if tx_hash_raw.startswith('0x') else '0x' + tx_hash_raw
        
        # Get transaction details (use cache if available)
        if tx_hash not in tx_cache:
            tx = w3.eth.get_transaction(tx_hash)
            tx_receipt = w3.eth.get_transaction_receipt(tx_hash)
            block = w3.eth.get_block(tx_receipt['blockNumber'])
            tx_cache[tx_hash] = {'tx': tx, 'tx_receipt': tx_receipt, 'block': block}
        else:
            tx = tx_cache[tx_hash]['tx']
            tx_receipt = tx_cache[tx_hash]['tx_receipt']
            block = tx_cache[tx_hash]['block']
        
        # Decode event arguments
        # Transfer(address indexed from, address indexed to, uint256 value)
        # Topics: [event_signature, from, to]
        # Data: value (uint256)
        # Addresses in topics are 32-byte values, we need the last 20 bytes (40 hex chars)
        topic1_hex = event['topics'][1].hex() if hasattr(event['topics'][1], 'hex') else event['topics'][1]
        topic2_hex = event['topics'][2].hex() if hasattr(event['topics'][2], 'hex') else event['topics'][2]
        
        # Remove '0x' prefix if present and take last 40 chars (20 bytes = address)
        from_addr = '0x' + (topic1_hex[2:] if topic1_hex.startswith('0x') else topic1_hex)[-40:]
        to_addr = '0x' + (topic2_hex[2:] if topic2_hex.startswith('0x') else topic2_hex)[-40:]
        
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
        
        # Get the contract address that emitted the event
        event_contract_address = event['address']
        
        # Create event entry
        event_entry = {
            'timestamp': block['timestamp'],
            'blockNumber': tx_receipt['blockNumber'],
            'txOrder': tx_receipt['transactionIndex'],
            'txHash': tx_hash,
            'txFrom': tx['from'],
            'txTo': tx['to'] if tx['to'] else None,  # Handle contract creation
            'eventContractAddress': event_contract_address,
            'eventName': 'Transfer',
            'eventArgs': encoded_args
        }
        
        # Initialize array for this tx_hash if it doesn't exist
        if tx_hash not in existing_events:
            existing_events[tx_hash] = []
        
        # Check for duplicates based on eventName and eventArgs
        is_duplicate = False
        for existing_event in existing_events[tx_hash]:
            if (existing_event['eventName'] == event_entry['eventName'] and 
                existing_event['eventArgs'] == event_entry['eventArgs']):
                is_duplicate = True
                break
        
        # Add event only if it's not a duplicate
        if not is_duplicate:
            existing_events[tx_hash].append(event_entry)
            new_events_count += 1
    
    if new_events_count > 0:
        print(f"Added {new_events_count} new Transfer events")
        save_events(existing_events)
    else:
        print("No new Transfer events found")
    
    # Count total events across all transactions
    total_events = sum(len(events) for events in existing_events.values())
    print(f"Total transactions: {len(existing_events)}")
    print(f"Total events in file: {total_events}")


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

