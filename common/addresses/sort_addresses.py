#!/usr/bin/env python3
"""
Address Sorter Script

This script reads all JSON files from the current directory (common/addresses),
sorts the data alphabetically by key, and overwrites the files with sorted data.

Usage:
    python3 sort_addresses.py

The script will:
1. Find all .json files in the current directory
2. Read each JSON file
3. Sort the data alphabetically by key
4. Write the sorted data back to the same file
5. Preserve the original formatting (indentation, etc.)
"""

import json
import os
import glob
from typing import Dict, Any

def sort_json_file(file_path: str) -> bool:
    """
    Sort a JSON file alphabetically by key and save it back.
    
    Args:
        file_path: Path to the JSON file
        
    Returns:
        bool: True if successful, False otherwise
    """
    try:
        # Read the JSON file
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Sort the data alphabetically by key
        sorted_data = dict(sorted(data.items()))
        
        # Write the sorted data back to the file with proper formatting
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(sorted_data, f, indent=4, separators=(',', ': '))
        
        print(f"✅ Sorted: {os.path.basename(file_path)}")
        return True
        
    except json.JSONDecodeError as e:
        print(f"❌ JSON decode error in {file_path}: {e}")
        return False
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        return False

def main():
    """Main function to sort all JSON files in the current directory."""
    print("🔄 Starting address sorting process...")
    print("=" * 50)
    
    # Get current directory
    current_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Find all JSON files in the current directory
    json_files = glob.glob(os.path.join(current_dir, "*.json"))
    
    if not json_files:
        print("❌ No JSON files found in the current directory")
        return
    
    print(f"📁 Found {len(json_files)} JSON files to process:")
    for file_path in json_files:
        print(f"   - {os.path.basename(file_path)}")
    
    print("\n🔄 Processing files...")
    print("-" * 50)
    
    successful = 0
    failed = 0
    
    for file_path in json_files:
        if sort_json_file(file_path):
            successful += 1
        else:
            failed += 1
    
    print("-" * 50)
    print(f"✅ Successfully sorted: {successful} files")
    if failed > 0:
        print(f"❌ Failed to sort: {failed} files")
    
    print("🎉 Address sorting completed!")

if __name__ == "__main__":
    main()
