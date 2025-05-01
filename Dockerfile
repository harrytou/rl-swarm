# Use CUDA base image for GPU support
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# System dependencies from the guide
RUN apt-get update && apt-get upgrade -y && \
apt-get install -y \
screen \
curl \
iptables \
git \
wget \
lz4 \
jq \
automake \
autoconf \
htop \
nvme-cli \
libgbm1 \
pkg-config \
libssl-dev \
libleveldb-dev \
clang \
bsdmainutils \
ncdu \
unzip \
python3 \
python3-pip \
python3-venv \
python3-dev \
openssh-server \
tini \
&& rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN python3 -m pip install --upgrade pip

# By default, we’ll assume we’re using the root user’s authorized_keys
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Add a build argument for your public key if you want to pass it directly during build
ARG SSH_PUBLIC_KEY
RUN echo "${SSH_PUBLIC_KEY}" >> /root/.ssh/authorized_keys && \
chmod 600 /root/.ssh/authorized_keys

# Install Node.js 22.x and Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
apt-get update && \
apt-get install -y nodejs && \
npm install -g yarn && \
curl -o- -L https://yarnpkg.com/install.sh | bash

# Add Yarn to PATH
ENV PATH="/root/.yarn/bin:/root/.config/yarn/global/node_modules/.bin:$PATH"

# Create working directory
WORKDIR /app

# Copy project files
COPY requirements-gpu.txt ./

# Install requirements
RUN pip install -r requirements-gpu.txt && \
    pip install flash-attn --no-build-isolation

# Declare build-time args
ARG NEXT_PUBLIC_PAYMASTER_POLICY_ID
ARG NEXT_PUBLIC_ALCHEMY_API_KEY
# Which swarm would you like to join (Math (A) or Math Hard (B))? [A/b]
# Hard is USE_BIG_SWARM=true
ARG USE_BIG_SWARM=true
# How many parameters (in billions)? [0.5, 1.5, 7, 32, 72]
ARG PARAM_B=72


# Make them available as environment vars during build
ENV SMART_CONTRACT_ADDRESS=${USE_BIG_SWARM:+0x6947c6E196a48B77eFa9331EC1E3e45f3Ee5Fd58}
ENV SMART_CONTRACT_ADDRESS=${SMART_CONTRACT_ADDRESS:-0x69C6e1D608ec64885E7b185d39b04B491a71768C}
ENV NEXT_PUBLIC_PAYMASTER_POLICY_ID=$NEXT_PUBLIC_PAYMASTER_POLICY_ID
ENV NEXT_PUBLIC_ALCHEMY_API_KEY=$NEXT_PUBLIC_ALCHEMY_API_KEY
ENV USE_BIG_SWARM=$USE_BIG_SWARM
ENV PARAM_B=$PARAM_B

# Install yarn dependencies in modal-login directory
COPY modal-login ./modal-login
WORKDIR /app/modal-login
RUN sed -i "3s/.*/SMART_CONTRACT_ADDRESS=$SMART_CONTRACT_ADDRESS/" .env
RUN yarn install
RUN yarn build

WORKDIR /app

# Environment variables
ENV CONNECT_TO_TESTNET="True"
ENV HUGGINGFACE_ACCESS_TOKEN="None"
ENV CUDA_VISIBLE_DEVICES="0"
ENV PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0

# Expose ports for both the Modal login server and SSH
EXPOSE 3000
EXPOSE 22

COPY hivemind_exp hivemind_exp
COPY run_rl_swarm.sh ./
COPY entrypoint.sh .

ENTRYPOINT ["/usr/bin/tini", "-g", "-s", "--"]
CMD ["./entrypoint.sh", "./run_rl_swarm.sh"]