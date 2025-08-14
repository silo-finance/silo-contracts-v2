#!/usr/bin/env python3
"""
Remove Duplicate Addresses Script

This script reads blockchain addresses from a JSON file, removes duplicates
using case-insensitive comparison, and saves the unique addresses back to a JSON file.

Usage:
    python3 remove_duplicates.py [input_file] [output_file]

If no arguments provided, uses default files:
    Input: users-54.json
    Output: users-54-unique.json
"""

import json
import sys
import logging
from typing import List, Set

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def load_addresses_from_json(file_path: str) -> List[str]:
    """Load addresses from JSON file (array of strings)."""
    try:
        with open(file_path, 'r') as f:
            addresses = json.load(f)
        
        if not isinstance(addresses, list):
            raise ValueError("JSON file must contain an array of addresses")
        
        logger.info(f"Loaded {len(addresses)} addresses from {file_path}")
        return addresses
        
    except FileNotFoundError:
        logger.error(f"File not found: {file_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON format in {file_path}: {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Error loading addresses from {file_path}: {e}")
        sys.exit(1)

def remove_duplicates_case_insensitive(addresses: List[str]) -> List[str]:
    """Remove duplicate addresses using case-insensitive comparison."""
    seen_addresses: Set[str] = set()
    unique_addresses: List[str] = []
    duplicates_count = 0
    
    for address in addresses:
        # Convert to lowercase for comparison
        address_lower = address.lower()
        
        if address_lower not in seen_addresses:
            seen_addresses.add(address_lower)
            unique_addresses.append(address)  # Keep original case
        else:
            duplicates_count += 1
            logger.info(f"Duplicate found: {address}")
    
    logger.info(f"Removed {duplicates_count} duplicate addresses")
    logger.info(f"Original count: {len(addresses)}")
    logger.info(f"Unique count: {len(unique_addresses)}")
    
    return unique_addresses

def save_addresses_to_json(addresses: List[str], file_path: str):
    """Save addresses to JSON file."""
    try:
        with open(file_path, 'w') as f:
            json.dump(addresses, f, indent=2)
        
        logger.info(f"Saved {len(addresses)} unique addresses to {file_path}")
        
    except Exception as e:
        logger.error(f"Error saving addresses to {file_path}: {e}")
        sys.exit(1)

def main():
    """Main function."""
    logger.info("Starting Duplicate Address Removal")
    
    # Get input and output file names from command line arguments or use defaults
    if len(sys.argv) >= 3:
        input_file = sys.argv[1]
        output_file = sys.argv[2]
    elif len(sys.argv) == 2:
        input_file = sys.argv[1]
        output_file = input_file.replace('.json', '-unique.json')
    else:
        input_file = "users-54.json"
        output_file = "users-54-unique.json"
    
    logger.info(f"Input file: {input_file}")
    logger.info(f"Output file: {output_file}")
    
    # Load addresses
    addresses = load_addresses_from_json(input_file)
    
    if not addresses:
        logger.error("No addresses found in input file")
        sys.exit(1)
    
    # Remove duplicates
    unique_addresses = remove_duplicates_case_insensitive(addresses)
    
    if len(unique_addresses) == 0:
        logger.error("No unique addresses found after deduplication")
        sys.exit(1)
    
    # Save unique addresses
    save_addresses_to_json(unique_addresses, output_file)
    
    logger.info("Duplicate removal completed successfully!")

if __name__ == "__main__":
    main()
