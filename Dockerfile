# DLC PyTorch 2.9, Python 3.12, CUDA 13.0
#
# Build order (must stay in sequence):
#   1. Base image: DLC has torch (GPU), Python 3.12, and a long LD_LIBRARY_PATH (CUDA/nvidia).
#   2. Install patchelf so patch-torchcodec can modify TorchCodec .so RPATH/RUNPATH.
#   3. Install torchcodec (CPU wheel), then av (PyAV with bundled FFmpeg in av.libs/), then
#      patch-torchcodec; run patch-torchcodec so it patches TorchCodec to find av.libs and torch/lib.
#   4. Set LD_LIBRARY_PATH to prepend av.libs and torch/lib (linker searches LD_LIBRARY_PATH before
#      RUNPATH, so we must put our libs first or verify fails in DLC).
#   5. Verify: patch-torchcodec --verify (import torchcodec and check it loads).
#
FROM public.ecr.aws/deep-learning-containers/pytorch-training:2.9.0-gpu-py312-cu130-ubuntu22.04-ec2

USER root

# 2. patchelf on PATH for patch-torchcodec
RUN for i in 1 2 3; do apt-get update && break || { [ "$i" -eq 3 ] && exit 1; sleep 10; }; done \
    && apt-get install -y --no-install-recommends patchelf \
    && rm -rf /var/lib/apt/lists/*

# 3. torchcodec (CPU) -> av (PyAV) -> patch-torchcodec; run patcher with LD_LIBRARY_PATH set
#    so its built-in verify (runs in same RUN) sees our libs before DLC CUDA paths
RUN pip install --no-cache-dir "torchcodec==0.9.*" --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir av patch-torchcodec \
    && export LD_LIBRARY_PATH="/usr/local/lib/python3.12/site-packages/av.libs:/usr/local/lib/python3.12/site-packages/torch/lib:${LD_LIBRARY_PATH:-}" \
    && patch-torchcodec

# 4. Prepend our libs to LD_LIBRARY_PATH so loader finds them before DLC CUDA paths
ENV LD_LIBRARY_PATH="/usr/local/lib/python3.12/site-packages/av.libs:/usr/local/lib/python3.12/site-packages/torch/lib:$LD_LIBRARY_PATH"

# 5. Verify TorchCodec loads
RUN patch-torchcodec --verify
