#!/usr/bin/env python3
"""
Silo Data Collector Script

This script reads blockchain addresses from a JSON file, calls ISilo contract methods
(maxWithdraw and maxRepay) for each address, and saves the results to a CSV file.

Environment variables required:
- RPC_SONIC: RPC endpoint URL
- SILO_ADDRESS: Address of the Silo contract

Usage:
    python silo_data_collector.py [input_json_file] [output_csv_file]
"""

import json
import csv
import os
import sys
from typing import List, Dict, Any
from web3 import Web3
from web3.exceptions import ContractLogicError
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# ISilo contract ABI - only the methods we need
ISILO_ABI = [
    {
        "inputs": [
            {"internalType": "address", "name": "_owner", "type": "address"},
            {"internalType": "enum ISilo.CollateralType", "name": "_collateralType", "type": "uint8"}
        ],
        "name": "maxWithdraw",
        "outputs": [{"internalType": "uint256", "name": "maxAssets", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "address", "name": "_borrower", "type": "address"}
        ],
        "name": "maxRepay",
        "outputs": [{"internalType": "uint256", "name": "assets", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    }
]

# CollateralType enum values
COLLATERAL_TYPE = {
    "Protected": 0,
    "Collateral": 1
}

# Hardcoded block number
BLOCK_NUMBER = 12345678  # Replace with actual block number

def load_addresses_from_json(file_path: str) -> List[str]:
    """Load addresses from JSON file."""
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
        
        # Handle different JSON structures
        if isinstance(data, list):
            # If it's a list of strings (addresses)
            addresses = data
        elif isinstance(data, dict):
            # If it's a dict with addresses as keys or in a specific field
            if 'addresses' in data:
                addresses = data['addresses']
            elif 'users' in data:
                addresses = data['users']
            else:
                # Assume all values are addresses
                addresses = list(data.values())
        else:
            raise ValueError("Unsupported JSON format")
        
        # Validate addresses
        valid_addresses = []
        for addr in addresses:
            if Web3.is_address(addr):
                valid_addresses.append(Web3.to_checksum_address(addr))
            else:
                logger.warning(f"Invalid address format: {addr}")
        
        logger.info(f"Loaded {len(valid_addresses)} valid addresses from {file_path}")
        return valid_addresses
    
    except FileNotFoundError:
        logger.error(f"File not found: {file_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON format: {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Error loading addresses: {e}")
        sys.exit(1)

def setup_web3() -> Web3:
    """Setup Web3 connection."""
    rpc_url = os.getenv('RPC_SONIC')
    if not rpc_url:
        logger.error("RPC_SONIC environment variable not set")
        sys.exit(1)
    
    try:
        w3 = Web3(Web3.HTTPProvider(rpc_url))
        if not w3.is_connected():
            logger.error("Failed to connect to RPC endpoint")
            sys.exit(1)
        
        logger.info(f"Connected to RPC endpoint: {rpc_url}")
        return w3
    except Exception as e:
        logger.error(f"Error setting up Web3: {e}")
        sys.exit(1)

def get_silo_contract(w3: Web3) -> Any:
    """Get Silo contract instance."""
    silo_address = os.getenv('SILO_ADDRESS')
    if not silo_address:
        logger.error("SILO_ADDRESS environment variable not set")
        sys.exit(1)
    
    try:
        silo_address = Web3.to_checksum_address(silo_address)
        contract = w3.eth.contract(address=silo_address, abi=ISILO_ABI)
        logger.info(f"Silo contract initialized at: {silo_address}")
        return contract
    except Exception as e:
        logger.error(f"Error initializing Silo contract: {e}")
        sys.exit(1)

def call_contract_methods(contract: Any, user_address: str, w3: Web3) -> Dict[str, Any]:
    """Call maxWithdraw and maxRepay methods for a user address."""
    results = {
        'silo_address': contract.address,
        'user_address': user_address,
        'maxWithdraw_protected': 0,
        'maxWithdraw_collateral': 0,
        'maxRepay': 0
    }
    
    try:
        # Call maxWithdraw for Protected collateral type
        try:
            max_withdraw_protected = contract.functions.maxWithdraw(
                user_address, 
                COLLATERAL_TYPE["Protected"]
            ).call(block_identifier=BLOCK_NUMBER)
            results['maxWithdraw_protected'] = max_withdraw_protected
        except ContractLogicError as e:
            logger.warning(f"maxWithdraw (Protected) failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"maxWithdraw (Protected) error for {user_address}: {e}")
        
        # Call maxWithdraw for Collateral type
        try:
            max_withdraw_collateral = contract.functions.maxWithdraw(
                user_address, 
                COLLATERAL_TYPE["Collateral"]
            ).call(block_identifier=BLOCK_NUMBER)
            results['maxWithdraw_collateral'] = max_withdraw_collateral
        except ContractLogicError as e:
            logger.warning(f"maxWithdraw (Collateral) failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"maxWithdraw (Collateral) error for {user_address}: {e}")
        
        # Call maxRepay
        try:
            max_repay = contract.functions.maxRepay(user_address).call(block_identifier=BLOCK_NUMBER)
            results['maxRepay'] = max_repay
        except ContractLogicError as e:
            logger.warning(f"maxRepay failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"maxRepay error for {user_address}: {e}")
        
        logger.info(f"Processed user: {user_address}")
        return results
    
    except Exception as e:
        logger.error(f"Error processing user {user_address}: {e}")
        return results

def save_to_csv(results: List[Dict[str, Any]], output_file: str):
    """Save results to CSV file."""
    try:
        with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['silo_address', 'user_address', 'maxWithdraw_protected', 'maxWithdraw_collateral', 'maxRepay']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            
            writer.writeheader()
            for result in results:
                writer.writerow(result)
        
        logger.info(f"Results saved to: {output_file}")
    except Exception as e:
        logger.error(f"Error saving to CSV: {e}")
        sys.exit(1)

def main():
    """Main function."""
    # Parse command line arguments
    if len(sys.argv) != 3:
        print("Usage: python silo_data_collector.py <input_json_file> <output_csv_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    logger.info("Starting Silo Data Collection")
    logger.info(f"Input file: {input_file}")
    logger.info(f"Output file: {output_file}")
    logger.info(f"Block number: {BLOCK_NUMBER}")
    
    # Load addresses
    addresses = load_addresses_from_json(input_file)
    if not addresses:
        logger.error("No valid addresses found")
        sys.exit(1)
    
    # Setup Web3 and contract
    w3 = setup_web3()
    contract = get_silo_contract(w3)
    
    # Process each address
    results = []
    for i, address in enumerate(addresses, 1):
        logger.info(f"Processing {i}/{len(addresses)}: {address}")
        result = call_contract_methods(contract, address, w3)
        results.append(result)
    
    # Save results
    save_to_csv(results, output_file)
    
    logger.info("Data collection completed successfully!")

if __name__ == "__main__":
    main()
