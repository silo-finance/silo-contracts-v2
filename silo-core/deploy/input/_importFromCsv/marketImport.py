"""
1. import data to `data.csv` for one market (only two rows from spreadsheet),
   note that csv file can have more lines, because cells can have new lines inside
2. run this script:
python3 silo-core/deploy/input/_importFromCsv/marketImport.py

3. copy data from `market.json` to your file and fill up missing fields
"""

import csv
import json
import os
import argparse


def to_percent(percentage_string):
    numeric_value = float(percentage_string.strip('%')) * 100
    return int(round(numeric_value, 0))

def find_config_name(configName: str, filename: str = 'silo-core/deploy/input/InterestRateModelConfigs.json') -> str:
    if configName == 'NA':
        return ''

    with open(filename, 'r') as f:
        data = json.load(f)

    for item in data:
        if item.get('name', '').lower() == configName.lower():
            return item['name']

    raise ValueError(f'Config with name "{configName}" not found.')

# Relative paths
script_dir = os.path.dirname(os.path.abspath(__file__))  # Script's location
input_file = os.path.join(script_dir, "data.csv")  # Relative path to the CSV file
print(f"input_file: {input_file}")

# JSON keys
keys = [
 "LP",
 "Blockchain", # Network
 "market", # Market
 "token", # Asset
 "address", # Asset Address
 "-", # Underlying address
 "Borrowable", # Borrowable?
 "maxLtv", # maxLTV
 "lt", # LT
 "liquidationTargetLtv", # LiquidationTargetLTV
 "liquidationFee", # Liquidation fee
 "interestRateModelConfig", # IRM config name
 "ORacle Provider", # "Oracle Provider Include a link to docs"
 "ORacle Address", # Oracle address
 "daoFee", # DAO fee
 "DAO's fee recpient", # DAO's fee recpient
 "deployerFee", # Deployer fee
 "Deployer's fee recpient", # Deployer's fee recpient
 "flashloanFee" # Flashloan fee
]

# Check if the input file exists
if not os.path.isfile(input_file):
    print(f"The file {input_file} does not exist!")
    exit(1)

# Read the CSV file and write data to JSON
with open(input_file, "r", newline="", encoding="utf-8") as csvfile:
    reader = csv.reader(csvfile)
    data = []

    for row in reader:
        if len(row) != len(keys):
            print("The number of columns in the CSV file does not match the number of keys.")
            print("cols:", len(row), "keys:", len(keys))
            print(row)
            exit(1)
        data.append({keys[i]: row[i] for i in range(len(keys))})

json_structure = {
    "deployer": "",
    "hookReceiver": "CLONE_IMPLEMENTATION",
    "hookReceiverImplementation": "SiloHookV1.sol",
    "daoFee": to_percent(data[0]["daoFee"]),
    "deployerFee": to_percent(data[0]["deployerFee"]),
    "token0": data[0]["token"],
    "solvencyOracle0": "",
    "maxLtvOracle0": "",
    "interestRateModel0": "InterestRateModelV2Factory.sol",
    "interestRateModelConfig0": find_config_name(data[0]["interestRateModelConfig"]),
    "maxLtv0": to_percent(data[0]["maxLtv"]),
    "lt0": to_percent(data[0]["lt"]),
    "liquidationTargetLtv0": to_percent(data[0]["liquidationTargetLtv"]),
    "liquidationFee0": to_percent(data[0]["liquidationFee"]),
    "flashloanFee0": to_percent(data[0]["flashloanFee"]),
    "callBeforeQuote0": False,

    "token1": data[1]["token"],
    "solvencyOracle1": "",
    "maxLtvOracle1": "",
    "interestRateModel1": "InterestRateModelV2Factory.sol",
    "interestRateModelConfig1": find_config_name(data[1]["interestRateModelConfig"]),
    "maxLtv1": to_percent(data[1]["maxLtv"]),
    "lt1": to_percent(data[1]["lt"]),
    "liquidationTargetLtv1": to_percent(data[1]["liquidationTargetLtv"]),
    "liquidationFee1": to_percent(data[1]["liquidationFee"]),
    "flashloanFee1": to_percent(data[1]["flashloanFee"]),
    "callBeforeQuote1": False
}

# Relative path to the JSON file
output_file = os.path.join(script_dir, f"Silo_{data[0]["token"]}_{data[1]["token"]}.json")

with open(output_file, "w", encoding="utf-8") as jsonfile:
    json.dump(json_structure, jsonfile, indent=4, ensure_ascii=False)
    jsonfile.write("\n")  # Add a newline at the end of the file

print(f"Data has been saved to {output_file}")


