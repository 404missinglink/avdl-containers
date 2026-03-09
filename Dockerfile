# Extends AWS Deep Learning Container PyTorch Training (PyTorch 2.9, Python 3.12, CUDA 13.0).
# ECR Public - no AWS login required. For region-specific ECR: 763104351884.dkr.ecr.<region>.amazonaws.com/pytorch-training:...
# See: https://aws.github.io/deep-learning-containers/reference/available_images/#pytorch-training
FROM public.ecr.aws/deep-learning-containers/pytorch-training:2.9.0-gpu-py312-cu130-ubuntu22.04-ec2

USER root

# Install FFmpeg (required by TorchCodec for video/audio decode/encode).
# TorchCodec loads .so files that depend on libavutil.so.56 etc.; Ubuntu puts them in
# /usr/lib/x86_64-linux-gnu. DLC images often set LD_LIBRARY_PATH to CUDA paths only,
# so the loader can miss system libs. See: https://github.com/meta-pytorch/torchcodec/issues/730
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && ldconfig

# So the loader finds FFmpeg shared libs at build and runtime.
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}

# Install TorchCodec 0.9 (matches torch 2.9 per torchcodec README compatibility table).
# CUDA build from PyTorch index; without --index-url pip would install CPU-only.
RUN pip install --no-cache-dir "torchcodec==0.9.*" \
    --index-url https://download.pytorch.org/whl/cu130

# Sanity check: torch and torchcodec importable (set LD_LIBRARY_PATH in same RUN so it is guaranteed).
RUN LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-} python -c "import torch; from torchcodec.decoders import VideoDecoder; print('PyTorch:', torch.__version__); print('TorchCodec OK')"
