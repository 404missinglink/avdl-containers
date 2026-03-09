# Extends AWS Deep Learning Container PyTorch Training (PyTorch 2.9, Python 3.12, CUDA 13.0).
# ECR Public - no AWS login required. For region-specific ECR: 763104351884.dkr.ecr.<region>.amazonaws.com/pytorch-training:...
# See: https://aws.github.io/deep-learning-containers/reference/available_images/#pytorch-training
FROM public.ecr.aws/deep-learning-containers/pytorch-training:2.9.0-gpu-py312-cu130-ubuntu22.04-ec2

USER root

# ---- Stage 1: FFmpeg ----
# Install FFmpeg (required by TorchCodec for video/audio decode/encode).
# TorchCodec loads .so files that depend on libavutil.so.56 etc.; Ubuntu puts them in
# /usr/lib/x86_64-linux-gnu. DLC images often set LD_LIBRARY_PATH to CUDA paths only,
# so the loader can miss system libs. See: https://github.com/meta-pytorch/torchcodec/issues/730
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && ldconfig

# Verify Stage 1: FFmpeg binary, shared libs, and ldconfig cache.
RUN echo "=== FFmpeg stage: binary ===" \
    && ffmpeg -version | head -5 \
    && echo "=== FFmpeg stage: shared libs in /usr/lib/x86_64-linux-gnu ===" \
    && ls -la /usr/lib/x86_64-linux-gnu/libavutil* /usr/lib/x86_64-linux-gnu/libavcodec* /usr/lib/x86_64-linux-gnu/libavformat* 2>/dev/null || true \
    && echo "=== FFmpeg stage: ldconfig cache (avutil) ===" \
    && ldconfig -p | grep -E "avutil|avcodec|avformat" || true \
    && echo "=== FFmpeg stage: default LD_LIBRARY_PATH ===" \
    && echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-<unset>}"

# Loader must find: (1) torchcodec's libtorchcodec_core4.so, (2) FFmpeg libs, (3) torch's libtorch.so etc.
# ldd showed libtorchcodec_core4.so found after adding TORCHCODEC_LIB; Python import still failed because
# when ctypes loads the .so, libtorch.so/libc10.so must be on the path (torch package puts them in torch/lib).
ENV TORCHCODEC_LIB=/usr/local/lib/python3.12/site-packages/torchcodec
ENV TORCH_LIB=/usr/local/lib/python3.12/site-packages/torch/lib
ENV LD_LIBRARY_PATH=${TORCHCODEC_LIB}:${TORCH_LIB}:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}

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
# ldd resolves all deps (torchcodec_core4, torch, c10, FFmpeg) but Python import still fails - likely
# the python process does not see LD_LIBRARY_PATH (e.g. DLC python wrapper). Use env(1) to force it.
RUN _LLP="${TORCHCODEC_LIB}:${TORCH_LIB}:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}" \
    && echo "=== Loader stage: LD_LIBRARY_PATH ===" \
    && echo "$_LLP" \
    && echo "=== Loader stage: ldd libtorchcodec_custom_ops4.so (FFmpeg 4) ===" \
    && LD_LIBRARY_PATH="$_LLP" ldd /usr/local/lib/python3.12/site-packages/torchcodec/libtorchcodec_custom_ops4.so 2>&1 | head -40 \
    && echo "=== Loader stage: LD_LIBRARY_PATH visible inside Python? ===" \
    && LD_LIBRARY_PATH="$_LLP" python -c "import os; p=os.environ.get('LD_LIBRARY_PATH',''); print('Yes, length', len(p)) if p else print('No')" \
    && echo "=== Loader stage: python import (via env so Python sees LD_LIBRARY_PATH) ===" \
    && env LD_LIBRARY_PATH="$_LLP" python -c "import torch; from torchcodec.decoders import VideoDecoder; print('PyTorch:', torch.__version__); print('TorchCodec OK')"
