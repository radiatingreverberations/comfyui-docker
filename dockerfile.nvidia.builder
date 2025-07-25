FROM nvidia/cuda:12.8.1-devel-ubuntu24.04

# Install required native build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3.12 python3.12-dev git \
    && ln -s /usr/bin/python3.12 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# Install uv
ADD https://github.com/astral-sh/uv/releases/download/0.7.16/uv-x86_64-unknown-linux-gnu.tar.gz /tmp/uv.tar.gz
RUN tar -xzf /tmp/uv.tar.gz --strip-components=1 && \
    mv uv /usr/local/bin/uv && \
    rm -rf /tmp/uv.tar.gz

# Configure uv cache to work with Docker BuildKit cache
ENV UV_CACHE_DIR=/cache/uv
ENV UV_LINK_MODE=copy

# Set app dir
WORKDIR /comfyui

# Prepare the virtual environment
RUN uv venv venv

# Install pytorch
ARG TORCH_VERSION=2.8.0
ARG TORCH_FLAVOR=test/cu128
RUN --mount=type=cache,target=/cache/uv,sharing=locked \
    . venv/bin/activate && \
    uv pip install torch==${TORCH_VERSION} torchvision torchaudio torchsde --extra-index-url https://download.pytorch.org/whl/${TORCH_FLAVOR}

# Build latest SageAttention
RUN --mount=type=cache,target=/cache/uv,sharing=locked \
    . venv/bin/activate && \
    uv pip install ninja wheel packaging && \
    git clone https://github.com/woct0rdho/SageAttention.git && \
    export TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0 12.0" && \
    export SAGEATTENTION_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST} && \
    cd SageAttention && \
    MAX_JOBS=1 NVCC_THREADS=4 uv build --wheel

# Build latest nunchaku
RUN --mount=type=cache,target=/cache/uv,sharing=locked \
    . venv/bin/activate && \
    git clone --recurse-submodules https://github.com/mit-han-lab/nunchaku.git && \
    export NUNCHAKU_INSTALL_MODE=ALL && \
    export NUNCHAKU_BUILD_WHEELS=1 && \
    cd nunchaku && \
    MAX_JOBS=1 NVCC_THREADS=4 uv build --wheel