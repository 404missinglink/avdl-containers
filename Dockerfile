# Extends AWS Deep Learning Container PyTorch Training (PyTorch 2.9, Python 3.12, CUDA 13.0).
# ECR Public - no AWS login required. For region-specific ECR: 763104351884.dkr.ecr.<region>.amazonaws.com/pytorch-training:...
# See: https://aws.github.io/deep-learning-containers/reference/available_images/#pytorch-training
FROM public.ecr.aws/deep-learning-containers/pytorch-training:2.9.0-gpu-py312-cu130-ubuntu22.04-ec2

USER root

# ---- Stage 1: FFmpeg via Miniforge (conda-forge only, no Anaconda ToS) ----
# TorchCodec needs FFmpeg with specific sonames; conda-forge provides a known-good build.
# Miniforge uses conda-forge as default and avoids Anaconda Terms of Service in CI.
# Training still runs with the DLC's Python; we only add /opt/conda/lib to LD_LIBRARY_PATH.
ARG MINIFORGE_VERSION=25.11.0-1
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sL "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh" -o /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -bfp /opt/conda \
    && rm /tmp/miniforge.sh \
    && /opt/conda/bin/conda config --system --set channel_priority strict \
    && /opt/conda/bin/conda config --system --prepend channels conda-forge \
    && /opt/conda/bin/conda config --system --remove channels defaults 2>/dev/null || true \
    && /opt/conda/bin/conda install -y ffmpeg \
    && /opt/conda/bin/conda clean -afy

# Verify Stage 1: Conda FFmpeg binary and shared libs.
RUN echo "=== FFmpeg stage: conda binary ===" \
    && /opt/conda/bin/ffmpeg -version | head -5 \
    && echo "=== FFmpeg stage: conda lib (avutil, avcodec, avformat) ===" \
    && ls -la /opt/conda/lib/libavutil* /opt/conda/lib/libavcodec* /opt/conda/lib/libavformat* 2>/dev/null || true \
    && echo "=== FFmpeg stage: default LD_LIBRARY_PATH ===" \
    && echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-<unset>}"

# Loader must find: (1) torchcodec .so, (2) torch libs, (3) conda FFmpeg libs.
ENV CONDA_LIB=/opt/conda/lib
ENV PATH=/opt/conda/bin:${PATH}
ENV TORCHCODEC_LIB=/usr/local/lib/python3.12/site-packages/torchcodec
ENV TORCH_LIB=/usr/local/lib/python3.12/site-packages/torch/lib
ENV LD_LIBRARY_PATH=${TORCHCODEC_LIB}:${TORCH_LIB}:${CONDA_LIB}:${LD_LIBRARY_PATH:-}

# ---- Stage 2: TorchCodec pip install ----
# Install TorchCodec 0.9 (matches torch 2.9 per torchcodec README compatibility table).
# CUDA build from PyTorch index; without --index-url pip would install CPU-only.
RUN pip install --no-cache-dir "torchcodec==0.9.*" \
    --index-url https://download.pytorch.org/whl/cu130

# Verify Stage 2: pip show and list .so files.
RUN echo "=== TorchCodec stage: pip show ===" \
    && pip show torchcodec \
    && echo "=== TorchCodec stage: .so files in site-packages ===" \
    && ls -la /usr/local/lib/python3.12/site-packages/torchcodec/*.so 2>/dev/null || true

# ---- Stage 3: Loader and import ----
# LD_LIBRARY_PATH includes conda FFmpeg libs so torchcodec can load. Use env(1) so Python sees it.
RUN _LLP="${TORCHCODEC_LIB}:${TORCH_LIB}:${CONDA_LIB}:${LD_LIBRARY_PATH:-}" \
    && echo "=== Loader stage: LD_LIBRARY_PATH ===" \
    && echo "$_LLP" \
    && echo "=== Loader stage: ldd torchcodec .so (one of core4-8) ===" \
    && LD_LIBRARY_PATH="$_LLP" ldd /usr/local/lib/python3.12/site-packages/torchcodec/libtorchcodec_custom_ops4.so 2>&1 | head -40 \
    && echo "=== Loader stage: LD_LIBRARY_PATH visible inside Python? ===" \
    && LD_LIBRARY_PATH="$_LLP" python -c "import os; p=os.environ.get('LD_LIBRARY_PATH',''); print('Yes, length', len(p)) if p else print('No')" \
    && echo "=== Loader stage: python import (via env so Python sees LD_LIBRARY_PATH) ===" \
    && env LD_LIBRARY_PATH="$_LLP" python -c "import torch; from torchcodec.decoders import VideoDecoder; print('PyTorch:', torch.__version__); print('TorchCodec OK')"
