#!/usr/bin/env bash
set -e

ROOT=$PWD

# These environment variables will apply to all peers
export CONNECT_TO_TESTNET="True"
export HUGGINGFACE_ACCESS_TOKEN="None"

#Check if public multi-address is given else set to default
DEFAULT_PUB_MULTI_ADDRS=""
PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}

#Check if peer multi-address is given else set to default
DEFAULT_PEER_MULTI_ADDRS="/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ" # gensyn coordinator node
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}

#Check if host multi-address is given else set to default
DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

cleanup() {
    echo "Cleaning up script. Any running screens remain unless manually closed."
    exit 0
}
trap cleanup INT

# Default GPU_ID is 0 unless specified as first argument
GPU_ID="${1:-0}"

echo ">>> Running script for GPU=$GPU_ID ..."

# 1) Set up environment for this GPU
export CUDA_VISIBLE_DEVICES=$GPU_ID
API_PORT=$((3000 + GPU_ID))
export MODAL_LOGIN_PORT=$API_PORT
USER_DATA_SUFFIX=$GPU_ID

echo ">>> Starting login server on port $API_PORT..."
echo "USER_DATA_SUFFIX set to: $USER_DATA_SUFFIX"

cd "$ROOT"/modal-login || exit
yarn install
PORT=$API_PORT USER_DATA_SUFFIX=$USER_DATA_SUFFIX yarn start > "$ROOT"/login-server-"${USER_DATA_SUFFIX}".log 2>&1 &
SERVER_PID=$!
echo "Server PID: $SERVER_PID" > "$ROOT"/server_pid-"${USER_DATA_SUFFIX}".txt
cd "$ROOT"

echo "Please login at http://localhost:$API_PORT to create an Ethereum Server Wallet"

# 2) Wait for userData-${GPU_ID}.json
while [ ! -f "modal-login/temp-data/userData-${USER_DATA_SUFFIX}.json" ]; do
    echo "Waiting for userData-${USER_DATA_SUFFIX}.json to be created. Once you've logged in, it appears."
    sleep 5
done
echo ">>> userData-${USER_DATA_SUFFIX}.json found. Proceeding..."

# 3) Extract ORG_ID
ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' "modal-login/temp-data/userData-${USER_DATA_SUFFIX}.json")
echo "ORG_ID set to: $ORG_ID"

# 4) Wait for API key activation
echo "Waiting for API key to become activated..."
while true; do
    STATUS=$(curl -s "http://localhost:$API_PORT/api/get-api-key-status?orgId=$ORG_ID")
    if [[ "$STATUS" == "activated" ]]; then
        echo "API key is activated! Proceeding..."
        break
    else
        echo "Waiting for API key to be activated..."
        sleep 5
    fi
done

if ! command -v nvidia-smi >/dev/null 2>&1; then
    CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
elif [ -n "$CPU_ONLY" ]; then
    CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
else
    pip install -r "$ROOT/requirements_gpu.txt" > /dev/null
    CONFIG_PATH="$ROOT/hivemind_exp/configs/gpu/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
fi

# 6) Launch the single peer for this GPU
PORT=$((38331 + GPU_ID))
PEER_IDENTITY="swarm_${GPU_ID}.pem"
echo ">>> Launching Peer on GPU=$GPU_ID, port=$PORT, identity=$PEER_IDENTITY"
IDENTITY_PATH="$ROOT/${PEER_IDENTITY}"

python3 -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --modal_org_id "$ORG_ID" \
        --config "$CONFIG_PATH"

wait