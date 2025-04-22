#!/bin/bash

set -euo pipefail

# General arguments
ROOT=$PWD

# These environment variables will apply to all peers
export PUB_MULTI_ADDRS
export PEER_MULTI_ADDRS
export HOST_MULTI_ADDRS
export IDENTITY_PATH
export CONNECT_TO_TESTNET="True"
export HUGGINGFACE_ACCESS_TOKEN="None"
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120  # 2 minutes

# Check if public multi-address is given else set to default
DEFAULT_PUB_MULTI_ADDRS=""
PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}

# Check if peer multi-address is given else set to default
DEFAULT_PEER_MULTI_ADDRS="/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ" # gensyn coordinator node
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}

# Check if host multi-address is given else set to default
DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

# Will ignore any visible GPUs if set.
CPU_ONLY=${CPU_ONLY:-""}

# Function to parse peer ID from peerInfo.txt file
get_peer_id() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        # Extract the peer ID from the file (format: "Peer ID: XXXX")
        local peer_id=$(grep -o "Peer ID: [^ ]*" "$file_path" | cut -d' ' -f3)
        echo "$peer_id"
    else
        echo "Peer ID file not found: $file_path"
        return 1
    fi
}

# Function to send Slack notification with peer ID
send_slack_notification() {
    local peer_id="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [ -z "$SLACK_WEBHOOK_URL" ]; then
        echo "SLACK_WEBHOOK_URL is not set. Skipping Slack notification."
        return 1
    fi

    local payload=$(cat <<-'JSONPAYLOAD'
    {
    	"blocks": [
    		{
    			"type": "header",
    			"text": {
    				"type": "plain_text",
    				"text": "🛑 RL Swarm Peer Disconnected",
    				"emoji": true
    			}
    		},
    		{
    			"type": "section",
    			"text": {
    				"type": "mrkdwn",
    				"text": "A peer node has *exited* the swarm. Below are the details:"
    			}
    		},
    		{
    			"type": "divider"
    		},
    		{
    			"type": "section",
    			"text": {
    				"type": "mrkdwn",
    				"text": "*Peer ID:* `__PEER_ID__`\n *Timestamp*: `__TIMESTAMP__`"
    			}
    		}
    	]
    }
JSONPAYLOAD
    )
    # Then manually replace placeholders in `payload`:
    payload="${payload/__PEER_ID__/$peer_id}"
    payload="${payload/__TIMESTAMP__/$timestamp}"

    # Send to Slack
    curl -s -X POST \
        -H 'Content-type: application/json' \
        --data "${payload}" \
        "${SLACK_WEBHOOK_URL}"
}

cleanup() {
    echo "Cleaning up script. Any running screens remain unless manually closed."

    # Check for peerInfo.txt and send notification if it exists
    PEER_INFO_FILE="$ROOT/modal-login/peerInfo.txt"
    if [ -f "$PEER_INFO_FILE" ]; then
        PEER_ID=$(get_peer_id "$PEER_INFO_FILE")
        if [ -n "$PEER_ID" ]; then
            echo "Sending Slack notification with Peer ID: $PEER_ID"
            send_slack_notification "$PEER_ID"
        fi
    fi

    exit 0
}
trap cleanup INT TERM

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
while [ ! -f "persist/userData-${USER_DATA_SUFFIX}.json" ]; do
    echo "Waiting for userData-${USER_DATA_SUFFIX}.json to be created. Once you've logged in, it appears."
    sleep 5
done
echo ">>> userData-${USER_DATA_SUFFIX}.json found. Proceeding..."

# 3) Extract ORG_ID
ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' "persist/userData-${USER_DATA_SUFFIX}.json")
echo "ORG_ID set to: $ORG_ID"

echo ">>> Checking if Modal Login is active..."
active=0
for i in {1..10}; do
    if curl -sS --max-time 5 "http://localhost:$API_PORT" > /dev/null 2>&1; then
        echo "Modal Login is active (attempt $i/10). Proceeding..."
        active=1
        break
    else
        echo "Attempt $i/10: Modal Login is not active. Waiting 5 seconds..."
        sleep 5
    fi
done

if [ $active -eq 0 ]; then
    echo "Error: Modal Login did not become active after 10 attempts. Exiting."
    exit 1
fi


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
mkdir -p "$ROOT/persist"
IDENTITY_PATH="$ROOT/persist/${PEER_IDENTITY}"

python3 -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --modal_org_id "$ORG_ID" \
        --config "$CONFIG_PATH" 2>&1 | tee "$ROOT/persist/rl_swarm_${TIMESTAMP}_gpu${GPU_ID:-0}.log"

wait