#!/usr/bin/env python3
"""
Avalanche Silo Analyzer Script

This script reads all Avalanche SiloConfig addresses from silo-core/deploy/silo/_siloDeployments.json
and for each config prints: factory address and implementation address so we can check what version was deployed

Environment variables required:
- RPC_AVALANCHE: Avalanche RPC endpoint URL (optional, defaults to public RPC)

Usage:
    python3 scripts/avalanche_silo_analyzer.py
"""

import json
import os
import sys
from typing import Dict, Any, Tuple
from web3 import Web3
from web3.exceptions import ContractLogicError
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Avalanche RPC URL - can be overridden by environment variable
DEFAULT_AVALANCHE_RPC = "https://api.avax.network/ext/bc/C/rpc"
AVALANCHE_RPC = os.getenv('RPC_AVALANCHE', DEFAULT_AVALANCHE_RPC)

# Minimal ABI for ISiloConfig - only the getSilos method we need
ISILO_CONFIG_ABI = [
    {
        "inputs": [],
        "name": "getSilos",
        "outputs": [
            {"internalType": "address", "name": "silo0", "type": "address"},
            {"internalType": "address", "name": "silo1", "type": "address"}
        ],
        "stateMutability": "view",
        "type": "function"
    }
]

# Minimal ABI for ISilo - only the factory method we need
ISILO_ABI = [
    {
        "inputs": [],
        "name": "factory",
        "outputs": [
            {"internalType": "address", "name": "siloFactory", "type": "address"}
        ],
        "stateMutability": "view",
        "type": "function"
    }
]


def load_silo_deployments() -> Dict[str, Any]:
    """Load silo deployments from JSON file."""
    json_file_path = "silo-core/deploy/silo/_siloDeployments.json"
    
    try:
        with open(json_file_path, 'r') as f:
            data = json.load(f)
        logger.info(f"Successfully loaded silo deployments from {json_file_path}")
        return data
    except FileNotFoundError:
        logger.error(f"File not found: {json_file_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON in {json_file_path}: {e}")
        sys.exit(1)

def get_avalanche_silo_configs(deployments: Dict[str, Any]) -> Dict[str, str]:
    """Extract Avalanche SiloConfig addresses from deployments data."""
    if 'avalanche' not in deployments:
        logger.error("No 'avalanche' section found in deployments JSON")
        return {}
    
    avalanche_configs = deployments['avalanche']
    logger.info(f"Found {len(avalanche_configs)} Avalanche SiloConfig addresses")
    
    return avalanche_configs

def connect_to_avalanche() -> Web3:
    """Connect to Avalanche network."""
    try:
        w3 = Web3(Web3.HTTPProvider(AVALANCHE_RPC))
        
        # Test connection
        if not w3.is_connected():
            raise Exception("Failed to connect to Avalanche network")
        
        # Get latest block to verify connection
        latest_block = w3.eth.block_number
        logger.info(f"Connected to Avalanche network. Latest block: {latest_block}")
        
        return w3
    except Exception as e:
        logger.error(f"Failed to connect to Avalanche network: {e}")
        sys.exit(1)


def get_implementation_from_bytecode(w3: Web3, proxy_address: str) -> str:
    """Get implementation address from minimal proxy bytecode (ERC-1167)."""
    try:
        # Get the runtime bytecode of the proxy contract
        bytecode = w3.eth.get_code(proxy_address)
        
        if len(bytecode) == 0:
            return "NO_CODE"
        
        # Convert to hex string
        bytecode_hex = bytecode.hex()
        
        # For minimal proxy (ERC-1167), implementation address is at bytes 10-30 (20 bytes)
        # In hex string, this is at positions 20-60 (40 hex characters)
        if len(bytecode_hex) >= 60:
            implementation_hex = bytecode_hex[20:60]
            implementation_address = w3.to_checksum_address('0x' + implementation_hex)
            
            # Validate that it's not all zeros
            if implementation_address != "0x0000000000000000000000000000000000000000":
                return implementation_address
        
        return "NO_IMPL"
    except Exception as e:
        logger.warning(f"Error reading implementation from bytecode for {proxy_address}: {e}")
        return "ERROR"

def get_silos_from_config(w3: Web3, config_address: str) -> Tuple[str, str, str, str]:
    """Call getSilos() on a SiloConfig contract and return silo0, silo1, factory address, and implementation address."""
    try:
        # Create SiloConfig contract instance
        config_contract = w3.eth.contract(address=config_address, abi=ISILO_CONFIG_ABI)
        
        # Call getSilos()
        silo0, silo1 = config_contract.functions.getSilos().call()
        
        # Get factory address and implementation address from silo0
        factory_address = ""
        implementation_address = ""
        if silo0 and silo0 != "0x0000000000000000000000000000000000000000":
            try:
                # Get factory address
                silo_contract = w3.eth.contract(address=silo0, abi=ISILO_ABI)
                factory_address = silo_contract.functions.factory().call()
                
                # Get implementation address from minimal proxy bytecode
                implementation_address = get_implementation_from_bytecode(w3, silo0)
                
            except Exception as e:
                logger.warning(f"Error calling factory() for silo0 {silo0}: {e}")
                factory_address = "ERROR"
        
        return silo0, silo1, factory_address, implementation_address
    except ContractLogicError as e:
        logger.warning(f"Contract logic error for {config_address}: {e}")
        return "", "", "", ""
    except Exception as e:
        logger.warning(f"Error calling getSilos() for {config_address}: {e}")
        return "", "", "", ""

def main():
    """Main function to analyze Avalanche SiloConfigs."""
    logger.info("Starting Avalanche Silo Analyzer")
    
    # Load silo deployments
    deployments = load_silo_deployments()
    
    # Get Avalanche SiloConfig addresses
    avalanche_configs = get_avalanche_silo_configs(deployments)
    
    if not avalanche_configs:
        logger.error("No Avalanche SiloConfig addresses found")
        sys.exit(1)
    
    # Connect to Avalanche network
    w3 = connect_to_avalanche()
    
    # Process each SiloConfig
    logger.info("Processing Avalanche SiloConfig addresses...")
    print("\n" + "="*160)
    print("AVALANCHE SILO CONFIG ANALYSIS")
    print("="*160)
    print(f"{'SiloConfig Name':<30} {'SiloConfig Address':<42} {'Silo0 Address':<42} {'Factory Address':<42} {'Implementation':<42}")
    print("-"*160)
    
    successful_calls = 0
    failed_calls = 0
    
    for config_name, config_address in avalanche_configs.items():
        silo0, silo1, factory_address, implementation_address = get_silos_from_config(w3, config_address)
        
        if silo0 and silo1:
            print(f"{config_name:<30} {config_address:<42} {silo0:<42} {factory_address:<42} {implementation_address:<42}")
            successful_calls += 1
        else:
            print(f"{config_name:<30} {config_address:<42} {'ERROR':<42} {'ERROR':<42} {'ERROR':<42}")
            failed_calls += 1
    
    print("-"*160)
    print(f"Total SiloConfigs processed: {len(avalanche_configs)}")
    print(f"Successful calls: {successful_calls}")
    print(f"Failed calls: {failed_calls}")
    print("="*160)
    
    if failed_calls > 0:
        logger.warning(f"{failed_calls} calls failed. Check the logs above for details.")
    
    logger.info("Avalanche Silo Analyzer completed")

if __name__ == "__main__":
    main()
