#!/usr/bin/env python3
"""
Silo Data Collector Script

This script reads blockchain addresses from a JSON file, calls ISilo contract methods
for each address, and saves the results to a CSV file.

Environment variables required:
- RPC_SONIC: RPC endpoint URL

Usage:
    python3 silo_data_collector.py

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

# CollateralType enum values
COLLATERAL_TYPE = {
    "Protected": 0,
    "Collateral": 1
}

# Hardcoded block number
BLOCK_NUMBER = 42282562  # Replace with actual block number

# Hardcoded SiloLens address
SILO_LENS_ADDRESS = "0xB95AD415b0fcE49f84FbD5B26b14ec7cf4822c69"

# Hardcoded Silo addresses
SILO0_ADDRESS = "0x04f124bF435545a3c79A8EE3Ffb6C51213CF5175"
SILO1_ADDRESS = "0xbE0D3c8801206CC9f35A6626f90ef9F4f2983A3D"



def load_abi_from_file(abi_file_path: str) -> List[Dict]:
    """Load ABI from JSON file."""
    try:
        with open(abi_file_path, 'r') as f:
            abi_data = json.load(f)
        
        if 'abi' in abi_data:
            return abi_data['abi']
        else:
            return abi_data  # Assume the file contains ABI directly
        
    except FileNotFoundError:
        logger.error(f"ABI file not found: {abi_file_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        logger.error(f"Invalid ABI JSON format: {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Error loading ABI: {e}")
        sys.exit(1)

def get_file_names() -> tuple[str, str]:
    """Generate input and output file names."""
    input_file = "users-54.json"
    output_file = "silo-54-results.csv"
    
    return input_file, output_file

def load_addresses_from_json(file_path: str) -> List[str]:
    """Load addresses from JSON file (array of strings)."""
    try:
        with open(file_path, 'r') as f:
            addresses = json.load(f)
        
        if not isinstance(addresses, list):
            raise ValueError("JSON file must contain an array of addresses")
        
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

def get_silo_contract(w3: Web3, silo_address: str, abi: List[Dict]) -> Any:
    """Get Silo contract instance."""
    try:
        silo_address = Web3.to_checksum_address(silo_address)
        contract = w3.eth.contract(address=silo_address, abi=abi)
        logger.info(f"Silo contract initialized at: {silo_address}")
        return contract
    except Exception as e:
        logger.error(f"Error initializing Silo contract: {e}")
        sys.exit(1)

def get_silo_lens_contract(w3: Web3, silo_lens_abi: List[Dict]) -> Any:
    """Get SiloLens contract instance."""
    try:
        silo_lens_address = Web3.to_checksum_address(SILO_LENS_ADDRESS)
        contract = w3.eth.contract(address=silo_lens_address, abi=silo_lens_abi)
        logger.info(f"SiloLens contract initialized at: {silo_lens_address}")
        return contract
    except Exception as e:
        logger.error(f"Error initializing SiloLens contract: {e}")
        sys.exit(1)

def get_silo_liquidity(contract: Any, silo_name: str) -> int:
    """Get liquidity from Silo contract."""
    try:
        liquidity = contract.functions.getLiquidity().call(block_identifier=BLOCK_NUMBER)
        logger.info(f"{silo_name} liquidity: {liquidity}")
        return liquidity
    except ContractLogicError as e:
        logger.warning(f"getLiquidity failed for {silo_name}: {e}")
        return 0
    except Exception as e:
        logger.warning(f"getLiquidity error for {silo_name}: {e}")
        return 0

def call_contract_methods(silo0_contract: Any, silo1_contract: Any, silo_lens_contract: Any, user_address: str, w3: Web3) -> Dict[str, Any]:
    """Call methods for a user address using silo0 for collateral and silo1 for maxRepay."""
    results = {
        'user_address': user_address,
        'total_underlying_collateral': 0,
        'maxWithdraw_protected': 0,
        'maxWithdraw_collateral': 0,
        'user_ltv': 0,
        'maxRepay': 0,
        'debt_5percent': 0
    }
    
    try:
        # Call maxWithdraw for Protected collateral type (silo0)
        try:
            max_withdraw_protected = silo0_contract.functions.maxWithdraw(
                user_address, 
                COLLATERAL_TYPE["Protected"]
            ).call(block_identifier=BLOCK_NUMBER)
            results['maxWithdraw_protected'] = max_withdraw_protected
        except ContractLogicError as e:
            logger.warning(f"maxWithdraw (Protected) failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"maxWithdraw (Protected) error for {user_address}: {e}")
        
        # Call maxWithdraw for Collateral type (silo0)
        try:
            max_withdraw_collateral = silo0_contract.functions.maxWithdraw(
                user_address, 
                COLLATERAL_TYPE["Collateral"]
            ).call(block_identifier=BLOCK_NUMBER)
            results['maxWithdraw_collateral'] = max_withdraw_collateral
        except ContractLogicError as e:
            logger.warning(f"maxWithdraw (Collateral) failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"maxWithdraw (Collateral) error for {user_address}: {e}")
        
        # Call getUserLTV (silo1)
        try:
            user_ltv = silo_lens_contract.functions.getUserLTV(silo1_contract.address, user_address).call(block_identifier=BLOCK_NUMBER)
            results['user_ltv'] = user_ltv
        except ContractLogicError as e:
            logger.warning(f"getUserLTV failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"getUserLTV error for {user_address}: {e}")
        
        # Call maxRepay (silo1)
        try:
            max_repay = silo1_contract.functions.maxRepay(user_address).call(block_identifier=BLOCK_NUMBER)
            results['maxRepay'] = max_repay
            # Calculate 5% of maxRepay
            results['debt_5percent'] = max_repay * 5 // 100
        except ContractLogicError as e:
            logger.warning(f"maxRepay failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"maxRepay error for {user_address}: {e}")
        
        # Call SiloLens collateralBalanceOfUnderlying (silo0)
        try:
            total_collateral = silo_lens_contract.functions.collateralBalanceOfUnderlying(
                silo0_contract.address, 
                user_address
            ).call(block_identifier=BLOCK_NUMBER)
            results['total_underlying_collateral'] = total_collateral
        except ContractLogicError as e:
            logger.warning(f"collateralBalanceOfUnderlying failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"collateralBalanceOfUnderlying error for {user_address}: {e}")
        
        logger.info(f"Processed user: {user_address}")
        return results
    
    except Exception as e:
        logger.error(f"Error processing user {user_address}: {e}")
        return results

def save_to_csv(results: List[Dict[str, Any]], output_file: str, silo0_liquidity: int, silo1_liquidity: int):
    """Save results to CSV file."""
    try:
        with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['user_address', 'total_underlying_collateral', 'maxWithdraw_protected', 'maxWithdraw_collateral', 'user_ltv', 'maxRepay', 'debt_5percent']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            
            writer.writeheader()
            
            # Write liquidity info as first row
            liquidity_row = {
                'user_address': f'silo0_liquidity:{silo0_liquidity},silo1_liquidity:{silo1_liquidity}',
                'total_underlying_collateral': '',
                'maxWithdraw_protected': '',
                'maxWithdraw_collateral': '',
                'user_ltv': '',
                'maxRepay': '',
                'debt_5percent': ''
            }
            writer.writerow(liquidity_row)
            
            for result in results:
                writer.writerow(result)
        
        logger.info(f"Results saved to: {output_file}")
    except Exception as e:
        logger.error(f"Error saving to CSV: {e}")
        sys.exit(1)

def main():
    """Main function."""
    logger.info("Starting Silo Data Collection")
    logger.info(f"Silo0 address: {SILO0_ADDRESS}")
    logger.info(f"Silo1 address: {SILO1_ADDRESS}")
    
    # Generate file names
    input_file, output_file = get_file_names()
    
    logger.info(f"Input file: {input_file}")
    logger.info(f"Output file: {output_file}")
    logger.info(f"Block number: {BLOCK_NUMBER}")
    
    # Load ABI from file
    abi_file_path = "../../deployments/sonic/Silo.sol.json"
    abi = load_abi_from_file(abi_file_path)
    logger.info(f"Loaded ABI from: {abi_file_path}")
    
    # Load SiloLens ABI from file
    silo_lens_abi_file_path = "../../deployments/sonic/SiloLens.sol.json"
    silo_lens_abi = load_abi_from_file(silo_lens_abi_file_path)
    logger.info(f"Loaded SiloLens ABI from: {silo_lens_abi_file_path}")
    
    # Load addresses
    addresses = load_addresses_from_json(input_file)
    if not addresses:
        logger.error("No valid addresses found")
        sys.exit(1)
    
    # Setup Web3 and contracts
    w3 = setup_web3()
    silo0_contract = get_silo_contract(w3, SILO0_ADDRESS, abi)
    silo1_contract = get_silo_contract(w3, SILO1_ADDRESS, abi)
    silo_lens_contract = get_silo_lens_contract(w3, silo_lens_abi)
    
    # Get liquidity from both Silo contracts
    silo0_liquidity = get_silo_liquidity(silo0_contract, "Silo0")
    silo1_liquidity = get_silo_liquidity(silo1_contract, "Silo1")
    
    # Process each address
    results = []
    for i, address in enumerate(addresses, 1):
        logger.info(f"Processing {i}/{len(addresses)}: {address}")
        result = call_contract_methods(silo0_contract, silo1_contract, silo_lens_contract, address, w3)
        results.append(result)
    
    # Save results
    save_to_csv(results, output_file, silo0_liquidity, silo1_liquidity)
    
    logger.info("Data collection completed successfully!")

if __name__ == "__main__":
    main()
