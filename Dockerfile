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
build-essential \
git \
wget \
lz4 \
jq \
make \
gcc \
nano \
automake \
autoconf \
tmux \
htop \
nvme-cli \
libgbm1 \
pkg-config \
libssl-dev \
libleveldb-dev \
tar \
clang \
bsdmainutils \
ncdu \
unzip \
python3 \
python3-pip \
python3-venv \
python3-dev \
ca-certificates \
gnupg \
openssh-server \
&& rm -rf /var/lib/apt/lists/*

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
COPY requirements-hivemind.txt requirements.txt requirements_gpu.txt ./

# Set up Python virtual environment and install requirements
RUN pip install --no-cache-dir -r requirements-hivemind.txt && \
pip install --no-cache-dir -r requirements.txt && \
pip install --no-cache-dir -r requirements_gpu.txt

# Install yarn dependencies in modal-login directory
COPY modal-login ./modal-login
WORKDIR /app/modal-login
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
COPY run_rl_swarm.sh run_rl_swarm_multi_gpu.sh ./
COPY entrypoint.sh .

ENTRYPOINT ["./entrypoint.sh"]
CMD ["./run_rl_swarm.sh", "0"]