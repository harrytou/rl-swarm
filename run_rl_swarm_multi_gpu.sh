#!/usr/bin/env bash
set -e

ROOT=$PWD

cleanup() {
    echo "Cleaning up script. Any running screens remain unless manually closed."
    exit 0
}
trap cleanup INT


echo "Running RL Swarm on multiple GPUs..."

# ------------------------------------------------------------------------------
# Install Yarn (if needed) and set up environment
# ------------------------------------------------------------------------------
source ~/.bashrc 2>/dev/null || true

if ! command -v yarn >/dev/null 2>&1; then
    echo "Yarn is not installed. Installing Yarn..."
    curl -o- -L https://yarnpkg.com/install.sh | bash
    echo 'export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
fi

source "$ROOT/.venv/bin/activate"

# Install Python Requirements
echo ">>> Installing Python requirements..."
pip install -r "$ROOT/requirements-hivemind.txt" > /dev/null
pip install -r "$ROOT/requirements.txt" > /dev/null
echo -e ">>> Done installing!\n"

# ------------------------------------------------------------------------------
# GPU detection: you can pick how many GPUs to use
# ------------------------------------------------------------------------------
NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | wc -l)
echo ">>> Detected $NUM_GPUS GPUs"

# ------------------------------------------------------------------------------
# Loop over each GPU and spawn a SCREEN session
# ------------------------------------------------------------------------------
for (( i=0; i<NUM_GPUS; i++ )); do
  SCREEN_NAME="swarm-${i}"
  echo ">>> Starting screen '$SCREEN_NAME' for GPU=$i"
  screen -S "$SCREEN_NAME" -dm bash -c "./run_rl_swarm.sh $i"
done

echo ""
echo "All peers are running in separate screens named 'swarm-0', 'swarm-1', etc."
echo "Attach to a screen with: screen -r swarm-0"
echo "Press Ctrl+C in a screen to kill that peer, or kill the entire session."