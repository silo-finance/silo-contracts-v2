#!/usr/bin/env python3
"""
Script to validate VERSION constants in Solidity contracts.

For release/hotfix PRs: checks if VERSION matches the branch version.
For regular PRs: checks if VERSION is higher than the last tag.
"""

import re
import sys
import os
import subprocess
from pathlib import Path
from typing import Optional, Tuple, List
from packaging import version


def get_modified_sol_files() -> List[str]:
    """Get list of modified .sol files in contracts/* directories."""
    # In GitHub Actions PR context, use GITHUB_BASE_REF
    base_ref = os.environ.get('GITHUB_BASE_REF', 'main')
    head_ref = os.environ.get('GITHUB_HEAD_REF', None)
    
    # Try different approaches to get modified files
    diff_commands = []
    
    if head_ref:
        # PR context: compare head with base
        diff_commands.append(["git", "diff", "--name-only", "--diff-filter=AM", f"origin/{base_ref}...origin/{head_ref}"])
        diff_commands.append(["git", "diff", "--name-only", "--diff-filter=AM", f"{base_ref}...{head_ref}"])
    
    # Fallback options
    diff_commands.extend([
        ["git", "diff", "--name-only", "--diff-filter=AM", f"origin/{base_ref}...HEAD"],
        ["git", "diff", "--name-only", "--diff-filter=AM", f"origin/master...HEAD"],
        ["git", "diff", "--name-only", "--diff-filter=AM", "HEAD~1"],
    ])
    
    for cmd in diff_commands:
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            if result.stdout.strip():
                break
        except subprocess.CalledProcessError:
            continue
    else:
        # If all commands failed, return empty list
        return []
    
    modified_files = [f for f in result.stdout.strip().split('\n') if f]
    sol_files = [
        f for f in modified_files 
        if f.endswith('.sol') and '/contracts/' in f
    ]
    return sol_files


def extract_contract_name(file_path: str) -> str:
    """Extract contract name from file path."""
    # Get filename without extension
    filename = Path(file_path).stem
    return filename


def extract_version_constant(file_path: str) -> Optional[str]:
    """Extract VERSION constant or function value from Solidity file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # First, try to match constant: string public constant VERSION = "ContractName X.Y.Z";
        # or: string public constant VERSION = 'ContractName X.Y.Z';
        constant_pattern = r'string\s+public\s+constant\s+VERSION\s*=\s*["\']([^"\']+)["\']\s*;'
        match = re.search(constant_pattern, content)
        
        if match:
            return match.group(1)
        
        # If not found, try to match function: function VERSION() ... returns (string memory) { return "ContractName X.Y.Z"; }
        # This pattern handles multi-line function definitions with DOTALL flag
        # Match from function declaration through the return statement
        function_pattern = r'function\s+VERSION\(\)[^{]*?\{[^}]*?return\s+["\']([^"\']+)["\']\s*;'
        match = re.search(function_pattern, content, re.DOTALL)
        
        if match:
            return match.group(1)
        
        # More robust approach: find function VERSION() and extract return value from its body
        # Look for function VERSION() declaration
        function_start_match = re.search(r'function\s+VERSION\(\)', content)
        
        if function_start_match:
            # Find the opening brace of the function
            start_pos = function_start_match.end()
            brace_start = content.find('{', start_pos)
            
            if brace_start != -1:
                # Find matching closing brace
                brace_count = 0
                in_string = False
                string_char = None
                
                for i in range(brace_start, len(content)):
                    char = content[i]
                    
                    # Handle string literals (skip escaped quotes)
                    if char in ('"', "'") and (i == 0 or content[i-1] != '\\'):
                        if not in_string:
                            in_string = True
                            string_char = char
                        elif char == string_char:
                            in_string = False
                            string_char = None
                        continue
                    
                    if in_string:
                        continue
                    
                    # Count braces
                    if char == '{':
                        brace_count += 1
                    elif char == '}':
                        brace_count -= 1
                        if brace_count == 0:
                            # Found the end of the function
                            function_body = content[brace_start:i+1]
                            # Look for return statement in the function body
                            return_pattern = r'return\s+["\']([^"\']+)["\']\s*;'
                            return_match = re.search(return_pattern, function_body)
                            if return_match:
                                return return_match.group(1)
                            break
        
        return None
    except Exception as e:
        print(f"Error reading {file_path}: {e}", file=sys.stderr)
        return None


def parse_version_string(version_str: str) -> Tuple[Optional[str], Optional[str]]:
    """
    Parse version string like "SiloLens 4.0.0" into (contract_name, version).
    Returns (None, None) if format is invalid.
    """
    # Match: "ContractName X.Y.Z" or "ContractName X.Y.Z-rc.1" etc.
    pattern = r'^([A-Za-z0-9_]+)\s+([0-9]+\.[0-9]+\.[0-9]+(?:-[a-zA-Z0-9.-]+)?)$'
    match = re.match(pattern, version_str)
    
    if match:
        contract_name = match.group(1)
        version_num = match.group(2)
        return contract_name, version_num
    
    return None, None


def get_last_tag_version() -> Optional[str]:
    """Get the latest git tag version."""
    try:
        result = subprocess.run(
            ["git", "describe", "--tags", "--abbrev=0"],
            capture_output=True,
            text=True,
            check=True
        )
        tag = result.stdout.strip()
        # Remove 'v' prefix if present
        if tag.startswith('v'):
            tag = tag[1:]
        return tag
    except subprocess.CalledProcessError:
        return None


def get_branch_version() -> Optional[str]:
    """Extract version from branch name (release/X.Y.Z or hotfix/X.Y.Z)."""
    try:
        # Try to get branch name from GitHub environment or git
        branch_name = None
        
        # Check GitHub environment variables
        if 'GITHUB_HEAD_REF' in os.environ:
            branch_name = os.environ['GITHUB_HEAD_REF']
        elif 'GITHUB_REF_NAME' in os.environ:
            branch_name = os.environ['GITHUB_REF_NAME']
        else:
            # Fallback to git command
            result = subprocess.run(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"],
                capture_output=True,
                text=True,
                check=True
            )
            branch_name = result.stdout.strip()
        
        # Match release/X.Y.Z or hotfix/X.Y.Z
        pattern = r'^(?:release|hotfix)/(.+)$'
        match = re.match(pattern, branch_name)
        
        if match:
            return match.group(1)
        
        return None
    except Exception:
        return None


def validate_version_for_release_hotfix(file_path: str, expected_version: str) -> Tuple[bool, str]:
    """Validate VERSION constant for release/hotfix PRs."""
    version_str = extract_version_constant(file_path)
    
    if version_str is None:
        # No VERSION constant, skip
        return True, "No VERSION constant found, skipping"
    
    contract_name, version_num = parse_version_string(version_str)
    expected_contract_name = extract_contract_name(file_path)
    
    if contract_name is None or version_num is None:
        return False, f"Invalid VERSION format: '{version_str}'. Expected: 'ContractName X.Y.Z'"
    
    # Check contract name matches
    if contract_name != expected_contract_name:
        return False, f"Contract name mismatch: expected '{expected_contract_name}', got '{contract_name}'"
    
    # Check version matches
    if version_num != expected_version:
        return False, f"Version mismatch: expected '{expected_version}', got '{version_num}'"
    
    return True, f"✅ VERSION '{version_str}' is valid"


def validate_version_for_regular_pr(file_path: str, last_tag: Optional[str]) -> Tuple[bool, str]:
    """Validate VERSION constant for regular PRs."""
    version_str = extract_version_constant(file_path)
    
    if version_str is None:
        # No VERSION constant, skip
        return True, "No VERSION constant found, skipping"
    
    contract_name, version_num = parse_version_string(version_str)
    expected_contract_name = extract_contract_name(file_path)
    
    if contract_name is None or version_num is None:
        return False, f"Invalid VERSION format: '{version_str}'. Expected: 'ContractName X.Y.Z'"
    
    # Check contract name matches
    if contract_name != expected_contract_name:
        return False, f"Contract name mismatch: expected '{expected_contract_name}', got '{contract_name}'"
    
    # Check version is higher than last tag
    if last_tag is None:
        # No tags exist, any version is valid
        return True, f"✅ VERSION '{version_str}' is valid (no previous tags found)"
    
    try:
        # Compare versions (handles semantic versioning)
        if version.parse(version_num) > version.parse(last_tag):
            return True, f"✅ VERSION '{version_str}' is valid (higher than last tag {last_tag})"
        else:
            return False, f"Version '{version_num}' must be higher than last tag '{last_tag}'"
    except Exception as e:
        return False, f"Error comparing versions: {e}"


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "regular"
    
    modified_files = get_modified_sol_files()
    
    if not modified_files:
        print("No modified .sol files in contracts/* directories found.")
        sys.exit(0)
    
    print(f"Found {len(modified_files)} modified .sol file(s) in contracts/* directories:")
    for f in modified_files:
        print(f"  - {f}")
    print()
    
    errors = []
    
    if mode == "release-hotfix":
        expected_version = get_branch_version()
        if expected_version is None:
            print("❌ Could not extract version from branch name. Expected format: release/X.Y.Z or hotfix/X.Y.Z")
            sys.exit(1)
        
        print(f"Checking VERSION constants against branch version: {expected_version}\n")
        
        for file_path in modified_files:
            print(f"Checking {file_path}...")
            is_valid, message = validate_version_for_release_hotfix(file_path, expected_version)
            print(f"  {message}")
            
            if not is_valid:
                errors.append((file_path, message))
            print()
    
    else:  # regular PR
        last_tag = get_last_tag_version()
        if last_tag:
            print(f"Last tag version: {last_tag}\n")
        else:
            print("No previous tags found.\n")
        
        for file_path in modified_files:
            print(f"Checking {file_path}...")
            is_valid, message = validate_version_for_regular_pr(file_path, last_tag)
            print(f"  {message}")
            
            if not is_valid:
                errors.append((file_path, message))
            print()
    
    if errors:
        print("\n❌ Validation failed for the following files:")
        for file_path, error_msg in errors:
            print(f"  {file_path}: {error_msg}")
        sys.exit(1)
    
    print("\n✅ All VERSION constants are valid!")
    sys.exit(0)


if __name__ == "__main__":
    main()

