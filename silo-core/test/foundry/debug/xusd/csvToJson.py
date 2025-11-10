#!/usr/bin/env python3
"""
Script to convert CSV file to JSON format.
Reads CSV file and uses first line as headers/keys for JSON objects.

python3 silo-core/test/foundry/debug/xusd/csvToJson.py
"""

import csv
import json
import os

# Hardcoded path (relative to project root)
CSV_FILE_PATH = "silo-core/test/foundry/debug/xusd/data/stream_markets_positions (1).csv"

def csv_to_json():
    """Convert CSV file to JSON format."""
    # Get project root (assuming script is in silo-core/test/foundry/debug/xusd/)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, "..", "..", "..", "..", ".."))
    
    csv_path = os.path.join(project_root, CSV_FILE_PATH)
    # Generate JSON file path by replacing .csv extension with .json
    json_file_path = os.path.splitext(CSV_FILE_PATH)[0] + ".json"
    json_path = os.path.join(project_root, json_file_path)
    
    # Read CSV and convert to JSON
    data = []
    with open(csv_path, 'r', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            data.append(row)
    
    # Write JSON file
    with open(json_path, 'w', encoding='utf-8') as jsonfile:
        json.dump(data, jsonfile, indent=2, ensure_ascii=False)
    
    print(f"Successfully converted {len(data)} rows from CSV to JSON")
    print(f"CSV file: {csv_path}")
    print(f"JSON file: {json_path}")

if __name__ == "__main__":
    csv_to_json()

