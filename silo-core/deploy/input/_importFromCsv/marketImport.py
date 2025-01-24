"""
1. import data to `data.csv`
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


# Relative paths
script_dir = os.path.dirname(os.path.abspath(__file__))  # Script's location
input_file = os.path.join(script_dir, "data.csv")  # Relative path to the CSV file
output_file = os.path.join(script_dir, "market.json")  # Relative path to the JSON file
print(f"input_file: {input_file}")

# JSON keys
keys = [
 "LP",
 "Blockchain",
 "market",
 "token",
 "address",
 "-",
 "Borrowable",
 "maxLtv",
 "lt",
 "liquidationTargetLtv",
 "liquidationFee",
 "interestRateModelConfig",
 "ORacle Provider",
 "ORacle Address",
 "daoFee",
 "DAO's fee recpient",
 "deployerFee",
 "Deployer's fee recpient",
 "flashloanFee",
 "_2",
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
    "hookReceiverImplementation": "GaugeHookReceiver.sol",
    "daoFee": to_percent(data[0]["daoFee"]),
    "deployerFee": to_percent(data[0]["deployerFee"]),
    "token0": data[0]["token"],
    "solvencyOracle0": "",
    "maxLtvOracle0": "",
    "interestRateModel0": "InterestRateModelV2.sol",
    "interestRateModelConfig0": data[0]["interestRateModelConfig"],
    "maxLtv0": to_percent(data[0]["maxLtv"]),
    "lt0": to_percent(data[0]["lt"]),
    "liquidationTargetLtv0": to_percent(data[0]["liquidationTargetLtv"]),
    "liquidationFee0": to_percent(data[0]["liquidationFee"]),
    "flashloanFee0": to_percent(data[0]["flashloanFee"]),
    "callBeforeQuote0": False,

    "token1": data[1]["token"],
    "solvencyOracle1": "",
    "maxLtvOracle1": "",
    "interestRateModel1": "InterestRateModelV2.sol",
    "interestRateModelConfig1": data[1]["interestRateModelConfig"],
    "maxLtv1": to_percent(data[1]["maxLtv"]),
    "lt1": to_percent(data[1]["lt"]),
    "liquidationTargetLtv1": to_percent(data[1]["liquidationTargetLtv"]),
    "liquidationFee1": to_percent(data[1]["liquidationFee"]),
    "flashloanFee1": to_percent(data[1]["flashloanFee"]),
    "callBeforeQuote1": False
}

with open(output_file, "w", encoding="utf-8") as jsonfile:
    json.dump(json_structure, jsonfile, indent=4, ensure_ascii=False)
    jsonfile.write("\n")  # Add a newline at the end of the file

print(f"Data has been saved to {output_file}")


