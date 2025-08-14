#!/bin/bash

# Dependency installation script for macOS
# This script handles the externally-managed-environment issue on macOS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Installing Python dependencies for Silo Data Collector..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install Python 3.7+ and try again."
    exit 1
fi

# Check if web3 is already installed
if python3 -c "import web3" 2>/dev/null; then
    print_status "Web3 is already installed ✓"
    exit 0
fi

# Try different installation methods
print_status "Attempting to install web3..."

# Method 1: Try with --user flag
if pip3 install --user web3 2>/dev/null; then
    print_status "✓ Web3 installed successfully with --user flag"
    exit 0
fi

# Method 2: Try with pip3 --break-system-packages (for newer Python versions)
if pip3 install --break-system-packages web3 2>/dev/null; then
    print_status "✓ Web3 installed successfully with --break-system-packages"
    exit 0
fi

# Method 3: Create virtual environment
print_warning "System-wide installation failed. Creating virtual environment..."
if python3 -m venv venv 2>/dev/null; then
    print_status "✓ Virtual environment created"
    source venv/bin/activate
    if pip install web3; then
        print_status "✓ Web3 installed in virtual environment"
        print_status "To use the script, activate the virtual environment first:"
        print_status "  source venv/bin/activate"
        print_status "  python silo_data_colector.py <silo_address>"
        exit 0
    else
        print_error "Failed to install web3 in virtual environment"
        exit 1
    fi
fi

# Method 4: Manual installation instructions
print_error "All automatic installation methods failed."
print_status "Please install web3 manually using one of these methods:"
echo ""
print_status "Method 1 (Recommended):"
print_status "  pip3 install --user web3"
echo ""
print_status "Method 2 (For newer Python versions):"
print_status "  pip3 install --break-system-packages web3"
echo ""
print_status "Method 3 (Using Homebrew):"
print_status "  brew install python-web3"
echo ""
print_status "Method 4 (Using conda):"
print_status "  conda install -c conda-forge web3"
echo ""
print_status "After installation, run the script again."
exit 1
