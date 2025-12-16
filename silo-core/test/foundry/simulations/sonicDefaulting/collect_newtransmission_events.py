#!/usr/bin/env python3
"""
Script to collect NewTransmission events from a contract.
Only extracts the int192 answer field.

Usage: 
python3 silo-core/test/foundry/simulations/sonicDefaulting/collect_newtransmission_events.py 0x0BdbFF19543B20d0bc2d1eA08deE2be4C0b76743
"""

import sys
import json
import os
from pathlib import Path
from web3 import Web3
from eth_abi import encode, decode
from eth_utils import to_hex

# Hardcoded RPC URL
RPC_URL = "https://sonic-mainnet.g.alchemy.com/v2/aNrPwztzUMrRelRP2OkYVAQc0CHo4DJk"  # Update this to your actual RPC URL

# Hardcoded block range
FROM_BLOCK = 58050000
TO_BLOCK = 58061678  # Use 'latest' for latest block, or specific block number

# Output JSON file - save in the same directory as this script
SCRIPT_DIR = Path(__file__).parent.absolute()
OUTPUT_FILE = str(SCRIPT_DIR / "events.json")

# NewTransmission event signature
# NewTransmission(uint32 aggregatorRoundId, int192 answer, address transmitter, uint32 observationsTimestamp, int192[] observations, bytes observers, int192 juelsPerFeeCoin, bytes32 configDigest, uint40 epochAndRound)
# Only aggregatorRoundId is indexed, so answer is in the data field
NEW_TRANSMISSION_EVENT_SIGNATURE = "NewTransmission(uint32,int192,address,uint32,int192[],bytes,int192,bytes32,uint40)"


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
    NewTransmission event: only answer (int192)
    """
    answer = event_args['answer']
    
    # Encode as (int192,)
    encoded = encode(['int192'], [answer])
    return to_hex(encoded)


def collect_newtransmission_events(contract_address):
    """Collect NewTransmission events from the contract."""
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    
    if not w3.is_connected():
        print(f"Error: Could not connect to RPC at {RPC_URL}")
        sys.exit(1)
    
    # Load existing events
    existing_events = load_existing_events()
    
    # Create event filter
    event_signature_hash = w3.keccak(text=NEW_TRANSMISSION_EVENT_SIGNATURE)
    
    # Get NewTransmission events from the contract
    print(f"Querying NewTransmission events from contract {contract_address}...")
    
    # Create filter for NewTransmission events
    # Note: aggregatorRoundId is indexed, so it will be in topics[1]
    transmission_filter = w3.eth.filter({
        'fromBlock': FROM_BLOCK,
        'toBlock': TO_BLOCK,
        'address': contract_address,
        'topics': [event_signature_hash]
    })
    
    events = transmission_filter.get_all_entries()
    print(f"Found {len(events)} NewTransmission events")
    
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
        # NewTransmission(uint32 indexed aggregatorRoundId, int192 answer, address transmitter, uint32 observationsTimestamp, int192[] observations, bytes observers, int192 juelsPerFeeCoin, bytes32 configDigest, uint40 epochAndRound)
        # Topics: [event_signature, aggregatorRoundId]
        # Data: answer (int192), transmitter (address), observationsTimestamp (uint32), observations (int192[]), observers (bytes), juelsPerFeeCoin (int192), configDigest (bytes32), epochAndRound (uint40)
        
        # Decode data field
        # Data contains: int192 answer, address transmitter, uint32 observationsTimestamp, int192[] observations, bytes observers, int192 juelsPerFeeCoin, bytes32 configDigest, uint40 epochAndRound
        # We need to decode all parameters to properly extract answer (due to dynamic types like arrays and bytes)
        data_hex = event['data'].hex() if hasattr(event['data'], 'hex') else event['data']
        if isinstance(data_hex, str) and data_hex.startswith('0x'):
            data_bytes = bytes.fromhex(data_hex[2:])
        elif isinstance(data_hex, bytes):
            data_bytes = data_hex
        else:
            data_bytes = bytes.fromhex(data_hex)
        
        # Decode all parameters to extract answer
        # Types: int192, address, uint32, int192[], bytes, int192, bytes32, uint40
        try:
            decoded = decode(
                ['int192', 'address', 'uint32', 'int192[]', 'bytes', 'int192', 'bytes32', 'uint40'],
                data_bytes
            )
            answer = decoded[0]  # First parameter is answer
        except Exception as e:
            print(f"Warning: Failed to decode answer for tx {tx_hash}: {e}")
            continue
        
        event_args = {
            'answer': answer
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
            'eventName': 'NewTransmission',
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
        print(f"Added {new_events_count} new NewTransmission events")
        save_events(existing_events)
    else:
        print("No new NewTransmission events found")
    
    # Count total events across all transactions
    total_events = sum(len(events) for events in existing_events.values())
    print(f"Total transactions: {len(existing_events)}")
    print(f"Total events in file: {total_events}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 collect_newtransmission_events.py <contract_address>")
        sys.exit(1)
    
    contract_address = sys.argv[1]
    
    # Validate address
    if not Web3.is_address(contract_address):
        print(f"Error: Invalid contract address: {contract_address}")
        sys.exit(1)
    
    # Normalize address (checksum)
    contract_address = Web3.to_checksum_address(contract_address)
    
    collect_newtransmission_events(contract_address)

