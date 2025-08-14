#!/bin/bash

# Silo Data Collector Runner Script
# This script helps set up the environment and run the data collector

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install Python 3.7+ and try again."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    print_error "pip3 is not installed. Please install pip and try again."
    exit 1
fi

# Check if web3 is already installed
if python3 -c "import web3" 2>/dev/null; then
    print_status "Web3 is already installed"
else
    print_status "Web3 not found, attempting to install..."
    
    # Install dependencies if requirements.txt exists
if [ -f "requirements.txt" ]; then
    print_status "Installing Python dependencies..."
    # Try to install with --user flag to avoid system-wide installation
    if pip3 install --user -r requirements.txt 2>/dev/null; then
        print_status "Dependencies installed successfully with --user flag"
    else
        print_warning "Failed to install with --user flag. Trying without pip..."
        print_status "Please install web3 manually: pip3 install --user web3"
    fi
else
    print_warning "requirements.txt not found. Installing web3 manually..."
    if pip3 install --user web3 2>/dev/null; then
        print_status "Web3 installed successfully with --user flag"
    else
        print_warning "Failed to install web3. Please install manually: pip3 install --user web3"
    fi
fi
fi

# Check environment variables
if [ -z "$RPC_SONIC" ]; then
    print_error "RPC_SONIC environment variable is not set."
    print_status "Please set it with: export RPC_SONIC='your-rpc-url'"
    exit 1
fi

# Check command line arguments
if [ $# -ne 1 ]; then
    print_error "Usage: $0 <silo_address>"
    print_status "Example: $0 0x435Ab368F5fCCcc71554f4A8ac5F5b922bC4Dc06"
    print_status "Make sure to set RPC_SONIC environment variable"
    exit 1
fi

SILO_ADDRESS=$1

# Generate expected file names
SILO_SHORT=${SILO_ADDRESS#0x}
INPUT_FILE="silo_0x${SILO_SHORT}_users.json"
OUTPUT_FILE="silo_0x${SILO_SHORT}_results.csv"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    print_error "Input file '$INPUT_FILE' does not exist."
    print_status "Please create the file with the list of user addresses."
    exit 1
fi

# Check if ABI file exists
ABI_FILE="../../contracts/interfaces/ISilo.json"
if [ ! -f "$ABI_FILE" ]; then
    print_error "ABI file '$ABI_FILE' does not exist."
    exit 1
fi

print_status "Starting Silo Data Collection..."
print_status "RPC URL: $RPC_SONIC"
print_status "Silo address: $SILO_ADDRESS"
print_status "Input file: $INPUT_FILE"
print_status "Output file: $OUTPUT_FILE"
print_status "ABI file: $ABI_FILE"

# Run the Python script
python3 silo_data_collector.py "$SILO_ADDRESS"

if [ $? -eq 0 ]; then
    print_status "Data collection completed successfully!"
    print_status "Results saved to: $OUTPUT_FILE"
else
    print_error "Data collection failed!"
    exit 1
fi
