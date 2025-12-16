#!/usr/bin/env python3
"""
Script to collect LiquidationCall events from a Silo contract.
Usage: python3 collect_liquidation_events.py <contract_address>
Usage: 

python3 silo-core/test/foundry/simulations/sonicDefaulting/collect_liquidation_events.py 0x6AAFD9Dd424541885fd79C06FDA96929CFD512f9

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

# LiquidationCall event signature
LIQUIDATION_CALL_EVENT_SIGNATURE = "LiquidationCall(address,address,address,uint256,uint256,bool)"


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
    LiquidationCall event: (address liquidator, address silo, address borrower, uint256 repayDebtAssets, uint256 withdrawCollateral, bool receiveSToken)
    """
    liquidator = event_args['liquidator']
    silo = event_args['silo']
    borrower = event_args['borrower']
    repay_debt_assets = event_args['repayDebtAssets']
    withdraw_collateral = event_args['withdrawCollateral']
    receive_s_token = event_args['receiveSToken']
    
    # Encode as (address, address, address, uint256, uint256, bool)
    encoded = encode(
        ['address', 'address', 'address', 'uint256', 'uint256', 'bool'],
        [liquidator, silo, borrower, repay_debt_assets, withdraw_collateral, receive_s_token]
    )
    return to_hex(encoded)


def collect_liquidation_events(contract_address):
    """Collect LiquidationCall events from the contract."""
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    
    if not w3.is_connected():
        print(f"Error: Could not connect to RPC at {RPC_URL}")
        sys.exit(1)
    
    # Load existing events
    existing_events = load_existing_events()
    
    # Create event filter
    event_signature_hash = w3.keccak(text=LIQUIDATION_CALL_EVENT_SIGNATURE)
    
    # Get LiquidationCall events from the contract
    print(f"Querying LiquidationCall events from contract {contract_address}...")
    
    # Create filter for LiquidationCall events
    liquidation_filter = w3.eth.filter({
        'fromBlock': FROM_BLOCK,
        'toBlock': TO_BLOCK,
        'address': contract_address,
        'topics': [event_signature_hash]
    })
    
    events = liquidation_filter.get_all_entries()
    print(f"Found {len(events)} LiquidationCall events")
    
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
        # LiquidationCall(address indexed liquidator, address indexed silo, address indexed borrower, uint256 repayDebtAssets, uint256 withdrawCollateral, bool receiveSToken)
        # Topics: [event_signature, liquidator, silo, borrower]
        # Data: repayDebtAssets (uint256), withdrawCollateral (uint256), receiveSToken (bool)
        # Addresses in topics are 32-byte values, we need the last 20 bytes (40 hex chars)
        topic1_hex = event['topics'][1].hex() if hasattr(event['topics'][1], 'hex') else event['topics'][1]
        topic2_hex = event['topics'][2].hex() if hasattr(event['topics'][2], 'hex') else event['topics'][2]
        topic3_hex = event['topics'][3].hex() if hasattr(event['topics'][3], 'hex') else event['topics'][3]
        
        # Remove '0x' prefix if present and take last 40 chars (20 bytes = address)
        liquidator = '0x' + (topic1_hex[2:] if topic1_hex.startswith('0x') else topic1_hex)[-40:]
        silo = '0x' + (topic2_hex[2:] if topic2_hex.startswith('0x') else topic2_hex)[-40:]
        borrower = '0x' + (topic3_hex[2:] if topic3_hex.startswith('0x') else topic3_hex)[-40:]
        
        # Decode data: uint256, uint256, bool
        # Data is HexBytes in web3.py LogEntry
        data_hex = event['data'].hex() if hasattr(event['data'], 'hex') else event['data']
        if isinstance(data_hex, str) and data_hex.startswith('0x'):
            data_hex = data_hex[2:]
        elif isinstance(data_hex, bytes):
            data_hex = data_hex.hex()
        
        # Each value is 32 bytes (64 hex chars)
        repay_debt_assets = int(data_hex[0:64], 16)  # First 32 bytes (uint256)
        withdraw_collateral = int(data_hex[64:128], 16)  # Next 32 bytes (uint256)
        receive_s_token = bool(int(data_hex[128:192], 16))  # Next 32 bytes (bool)
        
        event_args = {
            'liquidator': liquidator,
            'silo': silo,
            'borrower': borrower,
            'repayDebtAssets': repay_debt_assets,
            'withdrawCollateral': withdraw_collateral,
            'receiveSToken': receive_s_token
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
            'eventName': 'LiquidationCall',
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
        print(f"Added {new_events_count} new LiquidationCall events")
        save_events(existing_events)
    else:
        print("No new LiquidationCall events found")
    
    # Count total events across all transactions
    total_events = sum(len(events) for events in existing_events.values())
    print(f"Total transactions: {len(existing_events)}")
    print(f"Total events in file: {total_events}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python collect_liquidation_events.py <contract_address>")
        sys.exit(1)
    
    contract_address = sys.argv[1]
    
    # Validate address
    if not Web3.is_address(contract_address):
        print(f"Error: Invalid contract address: {contract_address}")
        sys.exit(1)
    
    # Normalize address (checksum)
    contract_address = Web3.to_checksum_address(contract_address)
    
    collect_liquidation_events(contract_address)

