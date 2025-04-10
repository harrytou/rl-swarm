#!/usr/bin/env bash
set -e

ROOT=$PWD

cleanup() {
    echo "Shutting down login server..."
    kill $SERVER_PID || true
    rm -f modal-login/temp-data/*.json
    exit 0
}
trap cleanup INT

# Starting the Modal login server
echo "Please login to create an Ethereum Server Wallet"
cd modal-login

# Source ~/.bashrc so any Yarn or Node changes are active
source ~/.bashrc

# Ensure Yarn is available; install if needed
if ! command -v yarn >/dev/null 2>&1; then
    echo "Yarn is not installed. Installing Yarn..."
    curl -o- -L https://yarnpkg.com/install.sh | sh
    echo 'export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
fi

# Install Node modules and run the login server in the background
yarn install
yarn dev 2>&1
SERVER_PID=$!
echo "Server PID: $SERVER_PID" > server_pid.txt
