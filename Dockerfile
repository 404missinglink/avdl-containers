# Extends AWS Deep Learning Container PyTorch Training (PyTorch 2.9, Python 3.12, CUDA 13.0).
# ECR Public - no AWS login required. For region-specific ECR: 763104351884.dkr.ecr.<region>.amazonaws.com/pytorch-training:...
# See: https://aws.github.io/deep-learning-containers/reference/available_images/#pytorch-training
FROM public.ecr.aws/deep-learning-containers/pytorch-training:2.9.0-gpu-py312-cu130-ubuntu22.04-ec2

USER root

# Install modern FFmpeg from static build (BtbN/FFmpeg-Builds). Apt only has 4.4 on Ubuntu 22.04.
# Releases: https://github.com/BtbN/FFmpeg-Builds/releases  Wiki: https://github.com/BtbN/FFmpeg-Builds/wiki/Latest
ARG FFMPEG_RELEASE=autobuild-2026-03-09-13-15
ARG FFMPEG_ARCHIVE=ffmpeg-n8.0.1-76-gfa4ee7ab3c-linux64-gpl-8.0.tar.xz
RUN apt-get update && apt-get install -y --no-install-recommends curl xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sL "https://github.com/BtbN/FFmpeg-Builds/releases/download/${FFMPEG_RELEASE}/${FFMPEG_ARCHIVE}" -o /tmp/ffmpeg.tar.xz \
    && tar -xJf /tmp/ffmpeg.tar.xz -C /tmp \
    && mv /tmp/ffmpeg-n*-linux64-gpl-8.0 /opt/ffmpeg \
    && rm /tmp/ffmpeg.tar.xz

ENV PATH="/opt/ffmpeg/bin:${PATH}"

# Verify FFmpeg is installed and runnable.
RUN ffmpeg -version
