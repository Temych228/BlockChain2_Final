#!/bin/bash
# Setup and build script for the DeFi Protocol project

set -e

echo "========================================="
echo "DeFi Protocol - Setup & Build Script"
echo "========================================="

# Check if Foundry is installed
if ! command -v forge &> /dev/null; then
    echo "Foundry not found. Installing..."
    curl -L https://foundry.paradigm.xyz | bash
    export PATH="$HOME/.foundry/bin:$PATH"
    foundryup
fi

echo ""
echo "Foundry version:"
forge --version

echo ""
echo "Installing dependencies..."
git submodule update --init --recursive

echo ""
echo "Compiling contracts..."
forge build --sizes

echo ""
echo "Running tests..."
forge test -vvv

echo ""
echo "Generating coverage report..."
forge coverage --report summary

echo ""
echo "Generating gas report..."
forge test --gas-report -vvv

echo ""
echo "========================================="
echo "Build & Test Complete!"
echo "========================================="
echo ""
echo "To run fork tests, set MAINNET_RPC_URL:"
echo "  export MAINNET_RPC_URL='your_rpc_url'"
echo "  forge test --match-contract ForkTest -vvv"
