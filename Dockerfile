# Extends AWS Deep Learning Container PyTorch Training (PyTorch 2.9, Python 3.12, CUDA 13.0).
# ECR Public - no AWS login required. For region-specific ECR: 763104351884.dkr.ecr.<region>.amazonaws.com/pytorch-training:...
# See: https://aws.github.io/deep-learning-containers/reference/available_images/#pytorch-training
FROM public.ecr.aws/deep-learning-containers/pytorch-training:2.9.0-gpu-py312-cu130-ubuntu22.04-ec2

USER root

# Install FFmpeg (apt; Ubuntu 22.04).
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Verify FFmpeg is installed and runnable.
RUN ffmpeg -version
