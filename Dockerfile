# DLC PyTorch 2.9, Python 3.12, CUDA 13.0
FROM public.ecr.aws/deep-learning-containers/pytorch-training:2.9.0-gpu-py312-cu130-ubuntu22.04-ec2

USER root

# ---- FFmpeg 8 (BtbN shared) ----
ARG FFMPEG_RELEASE=autobuild-2026-03-09-13-15
ARG FFMPEG_ARCHIVE=ffmpeg-n8.0.1-76-gfa4ee7ab3c-linux64-gpl-shared-8.0.tar.xz
RUN apt-get update && apt-get install -y --no-install-recommends curl xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sL "https://github.com/BtbN/FFmpeg-Builds/releases/download/${FFMPEG_RELEASE}/${FFMPEG_ARCHIVE}" -o /tmp/ffmpeg.tar.xz \
    && tar -xJf /tmp/ffmpeg.tar.xz -C /tmp \
    && mv /tmp/ffmpeg-n*-linux64-gpl-shared-8.0 /opt/ffmpeg \
    && rm /tmp/ffmpeg.tar.xz

ENV PATH="/opt/ffmpeg/bin:${PATH}"
RUN ffmpeg -version

# ---- TorchCodec ----
RUN pip install --no-cache-dir "torchcodec==0.9.*" --index-url https://download.pytorch.org/whl/cu130

ENV LD_LIBRARY_PATH=/usr/local/lib/python3.12/site-packages/torchcodec:/usr/local/lib/python3.12/site-packages/torch/lib:/opt/ffmpeg/lib:${LD_LIBRARY_PATH:-}
RUN python -c "import torch; from torchcodec.decoders import VideoDecoder; print('torch', torch.__version__, 'torchcodec OK')"
