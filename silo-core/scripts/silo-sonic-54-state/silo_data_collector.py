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
from decimal import Decimal

# Minimal ABI for ISiloOracle
ISILO_ORACLE_ABI = [
    {
        "inputs": [
            {"internalType": "address", "name": "_baseToken", "type": "address"}
        ],
        "name": "beforeQuote",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "uint256", "name": "_baseAmount", "type": "uint256"},
            {"internalType": "address", "name": "_baseToken", "type": "address"}
        ],
        "name": "quote",
        "outputs": [{"internalType": "uint256", "name": "quoteAmount", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "quoteToken",
        "outputs": [{"internalType": "address", "name": "", "type": "address"}],
        "stateMutability": "view",
        "type": "function"
    }
]

# Minimal ABI for ISiloConfig
ISILO_CONFIG_ABI = [
    {
        "inputs": [
            {"internalType": "address", "name": "_silo", "type": "address"}
        ],
        "name": "getConfig",
        "outputs": [
            {
                "components": [
                    {"internalType": "uint256", "name": "daoFee", "type": "uint256"},
                    {"internalType": "uint256", "name": "deployerFee", "type": "uint256"},
                    {"internalType": "address", "name": "silo", "type": "address"},
                    {"internalType": "address", "name": "token", "type": "address"},
                    {"internalType": "address", "name": "protectedShareToken", "type": "address"},
                    {"internalType": "address", "name": "collateralShareToken", "type": "address"},
                    {"internalType": "address", "name": "debtShareToken", "type": "address"},
                    {"internalType": "address", "name": "solvencyOracle", "type": "address"},
                    {"internalType": "address", "name": "maxLtvOracle", "type": "address"},
                    {"internalType": "address", "name": "interestRateModel", "type": "address"},
                    {"internalType": "uint256", "name": "maxLtv", "type": "uint256"},
                    {"internalType": "uint256", "name": "lt", "type": "uint256"},
                    {"internalType": "uint256", "name": "liquidationTargetLtv", "type": "uint256"},
                    {"internalType": "uint256", "name": "liquidationFee", "type": "uint256"},
                    {"internalType": "uint256", "name": "flashloanFee", "type": "uint256"},
                    {"internalType": "address", "name": "hookReceiver", "type": "address"},
                    {"internalType": "bool", "name": "callBeforeQuote", "type": "bool"}
                ],
                "internalType": "struct ISiloConfig.ConfigData",
                "name": "config",
                "type": "tuple"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    }
]

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)



# Hardcoded block number
BLOCK_NUMBER = 42282562  # Replace with actual block number

# Hardcoded SiloLens address
SILO_LENS_ADDRESS = "0xB95AD415b0fcE49f84FbD5B26b14ec7cf4822c69"

# Hardcoded Silo addresses
SILO0_ADDRESS = "0x04f124bF435545a3c79A8EE3Ffb6C51213CF5175"
SILO1_ADDRESS = "0xbE0D3c8801206CC9f35A6626f90ef9F4f2983A3D"

def handle_uint256(value) -> int:
    """Handle uint256 values properly, ensuring they fit in Python int."""
    if value is None:
        return 0
    
    # Convert to int if it's not already
    int_value = int(value)
    
    # Check if it's within uint256 range (0 to 2^256 - 1)
    if int_value < 0:
        logger.warning(f"Negative uint256 value detected: {value}, setting to 0")
        return 0
    
    # Python int can handle arbitrarily large numbers, so no upper bound check needed
    return int_value



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
    input_file = "users-54-unique.json"
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
        liquidity_handled = handle_uint256(liquidity)
        logger.info(f"{silo_name} liquidity: {liquidity_handled}")
        return liquidity_handled
    except ContractLogicError as e:
        logger.warning(f"getLiquidity failed for {silo_name}: {e}")
        return 0
    except Exception as e:
        logger.warning(f"getLiquidity error for {silo_name}: {e}")
        return 0

def get_silo_asset(contract: Any, silo_name: str) -> str:
    """Get asset address from a Silo contract."""
    try:
        asset = contract.functions.asset().call(block_identifier=BLOCK_NUMBER)
        logger.info(f"{silo_name} asset: {asset}")
        return asset
    except ContractLogicError as e:
        logger.warning(f"asset() failed for {silo_name}: {e}")
        return ""
    except Exception as e:
        logger.warning(f"asset() error for {silo_name}: {e}")
        return ""

def get_silo_config(contract: Any, silo_name: str) -> str:
    """Get config address from a Silo contract."""
    try:
        config = contract.functions.config().call(block_identifier=BLOCK_NUMBER)
        logger.info(f"{silo_name} config: {config}")
        return config
    except ContractLogicError as e:
        logger.warning(f"config() failed for {silo_name}: {e}")
        return ""
    except Exception as e:
        logger.warning(f"config() error for {silo_name}: {e}")
        return ""

def get_silo_config_data(w3: Web3, config_address: str, silo_address: str) -> Dict[str, Any]:
    """Get config data from SiloConfig contract."""
    try:
        config_contract = w3.eth.contract(address=config_address, abi=ISILO_CONFIG_ABI)
        
        config_data_tuple = config_contract.functions.getConfig(silo_address).call(block_identifier=BLOCK_NUMBER)
        logger.info(f"Config data for {silo_address}: {config_data_tuple}")
        
        # Convert tuple to dictionary using the ConfigData struct field names
        config_data = {
            'daoFee': config_data_tuple[0],
            'deployerFee': config_data_tuple[1],
            'silo': config_data_tuple[2],
            'token': config_data_tuple[3],
            'protectedShareToken': config_data_tuple[4],
            'collateralShareToken': config_data_tuple[5],
            'debtShareToken': config_data_tuple[6],
            'solvencyOracle': config_data_tuple[7],
            'maxLtvOracle': config_data_tuple[8],
            'interestRateModel': config_data_tuple[9],
            'maxLtv': config_data_tuple[10],
            'lt': config_data_tuple[11],
            'liquidationTargetLtv': config_data_tuple[12],
            'liquidationFee': config_data_tuple[13],
            'flashloanFee': config_data_tuple[14],
            'hookReceiver': config_data_tuple[15],
            'callBeforeQuote': config_data_tuple[16]
        }
        
        return config_data
    except Exception as e:
        logger.warning(f"getConfig failed for {silo_address}: {e}")
        return {}

def get_oracle_price(w3: Web3, oracle_address: str, asset_address: str) -> int:
    """Get price from oracle for 1e18 of asset."""
    if not oracle_address or oracle_address == "0x0000000000000000000000000000000000000000":
        logger.info(f"No oracle configured for asset {asset_address}, assuming price of 1e18")
        return 10**18
    
    try:
        oracle_contract = w3.eth.contract(address=oracle_address, abi=ISILO_ORACLE_ABI)
        
        # Get price for 1e18 of asset
        price = oracle_contract.functions.quote(10**18, asset_address).call(block_identifier=BLOCK_NUMBER)
        logger.info(f"Oracle price for {asset_address}: {price}")
        return handle_uint256(price)
    except ContractLogicError as e:
        logger.warning(f"Oracle quote failed for {asset_address}: {e}")
        return 10**18  # Default to 1e18
    except Exception as e:
        logger.warning(f"Oracle quote error for {asset_address}: {e}")
        return 10**18  # Default to 1e18

def fetch_silo_price(w3: Web3, silo_contract: Any, silo_name: str, silo_address: str) -> tuple[str, int]:
    """Fetch and print price for a single silo."""
    logger.info(f"=== Fetching {silo_name} Price ===")
    
    # Get asset
    asset = get_silo_asset(silo_contract, silo_name)
    if not asset:
        logger.error(f"Failed to get asset address for {silo_name}")
        return "", 0
    
    # Get config
    config = get_silo_config(silo_contract, silo_name)
    if not config:
        logger.error(f"Failed to get config address for {silo_name}")
        return "", 0
    
    # Get config data
    config_data = get_silo_config_data(w3, config, silo_address)
    if not config_data:
        logger.error(f"Failed to get config data for {silo_name}")
        return "", 0
    
    # Get solvency oracle address
    solvency_oracle = config_data.get('solvencyOracle', '')
    
    # Get price
    price = get_oracle_price(w3, solvency_oracle, asset)
    
    # Print result
    print(f"{silo_name} Asset: {asset}")
    print(f"{silo_name} Price (1e18): {price}")
    
    return asset, price

def fetch_silo_prices(w3: Web3, silo0_contract: Any, silo1_contract: Any):
    """Fetch and print prices for both silos."""
    logger.info("=== Fetching Silo Prices ===")
    
    # Fetch prices for both silos
    silo0_asset, silo0_price = fetch_silo_price(w3, silo0_contract, "Silo0", SILO0_ADDRESS)
    silo1_asset, silo1_price = fetch_silo_price(w3, silo1_contract, "Silo1", SILO1_ADDRESS)
    
    print(f"==================\n")

def call_contract_methods(silo0_contract: Any, silo1_contract: Any, silo_lens_contract: Any, user_address: str, w3: Web3) -> Dict[str, Any]:
    """Call methods for a user address using silo0 for collateral and silo1 for maxRepay."""
    results = {
        'user_address': user_address,
        'total_underlying_collateral': 0,
        'maxWithdraw_collateral': 0,
        'maxRepay': 0,
        'silo1_total_collateral': 0,
        'silo1_max_withdraw': 0,
        'silo0_maxRepay': 0,
        'user_ltv': 0
    }
    
    try:
        # Call SiloLens collateralBalanceOfUnderlying (silo0)
        try:
            total_collateral = silo_lens_contract.functions.collateralBalanceOfUnderlying(
                silo0_contract.address, 
                user_address
            ).call(block_identifier=BLOCK_NUMBER)
            results['total_underlying_collateral'] = handle_uint256(total_collateral)
        except ContractLogicError as e:
            logger.warning(f"collateralBalanceOfUnderlying failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"collateralBalanceOfUnderlying error for {user_address}: {e}")
        
        # Call maxWithdraw for Collateral type (silo0)
        try:
            max_withdraw_collateral = silo0_contract.functions.maxWithdraw(
                user_address
            ).call(block_identifier=BLOCK_NUMBER)
            results['maxWithdraw_collateral'] = handle_uint256(max_withdraw_collateral)
        except ContractLogicError as e:
            logger.warning(f"maxWithdraw (Collateral) failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"maxWithdraw (Collateral) error for {user_address}: {e}")
        

        
        # Call getUserLTV (silo1)
        try:
            user_ltv = silo_lens_contract.functions.getUserLTV(silo1_contract.address, user_address).call(block_identifier=BLOCK_NUMBER)
            results['user_ltv'] = handle_uint256(user_ltv)
        except ContractLogicError as e:
            logger.warning(f"getUserLTV failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"getUserLTV error for {user_address}: {e}")
        
        # Call maxRepay (silo1)
        try:
            max_repay = silo1_contract.functions.maxRepay(user_address).call(block_identifier=BLOCK_NUMBER)
            results['maxRepay'] = handle_uint256(max_repay)
        except ContractLogicError as e:
            logger.warning(f"maxRepay failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"maxRepay error for {user_address}: {e}")
        
        # Call SiloLens collateralBalanceOfUnderlying (silo1)
        try:
            silo1_total_collateral = silo_lens_contract.functions.collateralBalanceOfUnderlying(
                silo1_contract.address, 
                user_address
            ).call(block_identifier=BLOCK_NUMBER)
            results['silo1_total_collateral'] = handle_uint256(silo1_total_collateral)
        except ContractLogicError as e:
            logger.warning(f"silo1 collateralBalanceOfUnderlying failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"silo1 collateralBalanceOfUnderlying error for {user_address}: {e}")
        
        # Call maxWithdraw for Collateral type (silo1)
        try:
            silo1_max_withdraw = silo1_contract.functions.maxWithdraw(user_address).call(block_identifier=BLOCK_NUMBER)
            results['silo1_max_withdraw'] = handle_uint256(silo1_max_withdraw)
        except ContractLogicError as e:
            logger.warning(f"silo1 maxWithdraw failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"silo1 maxWithdraw error for {user_address}: {e}")
        
        # Call maxRepay (silo0)
        try:
            silo0_max_repay = silo0_contract.functions.maxRepay(user_address).call(block_identifier=BLOCK_NUMBER)
            results['silo0_maxRepay'] = handle_uint256(silo0_max_repay)
        except ContractLogicError as e:
            logger.warning(f"silo0 maxRepay failed for {user_address}: {e}")
        except Exception as e:
            logger.warning(f"silo0 maxRepay error for {user_address}: {e}")
        
        logger.info(f"Processed user: {user_address}")
        return results
    
    except Exception as e:
        logger.error(f"Error processing user {user_address}: {e}")
        return results

def save_to_csv(results: List[Dict[str, Any]], output_file: str, silo0_liquidity: int, silo1_liquidity: int):
    """Save results to CSV file."""
    try:
        with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['user_address', 'total_underlying_collateral', 'maxWithdraw_collateral', 'maxRepay', 'silo1_total_collateral', 'silo1_max_withdraw', 'silo0_maxRepay', 'user_ltv']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            
            writer.writeheader()
            
            # Write liquidity info as first row
            liquidity_row = {
                'user_address': f'silo0_liquidity:{silo0_liquidity},silo1_liquidity:{silo1_liquidity}',
                'total_underlying_collateral': '',
                'maxWithdraw_collateral': '',
                'maxRepay': '',
                'silo1_total_collateral': '',
                'silo1_max_withdraw': '',
                'silo0_maxRepay': '',
                'user_ltv': ''
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
    
    # Fetch and print prices for both silos
    fetch_silo_prices(w3, silo0_contract, silo1_contract)
    
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
