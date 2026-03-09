# DLC PyTorch 2.9, Python 3.12, CUDA 13.0
FROM public.ecr.aws/deep-learning-containers/pytorch-training:2.9.0-gpu-py312-cu130-ubuntu22.04-ec2

USER root

# ---- FFmpeg 8 (BtbN shared): one install for CLI and TorchCodec ----
RUN apt-get update && apt-get install -y --no-install-recommends curl patchelf xz-utils \
    && rm -rf /var/lib/apt/lists/*

ARG BTBN_FFMPEG_URL="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n8.0-latest-linux64-gpl-shared-8.0.tar.xz"
RUN curl -sL -o /tmp/ffmpeg.tar.xz "${BTBN_FFMPEG_URL}" \
    && mkdir -p /opt/ffmpeg \
    && tar -C /opt/ffmpeg --strip-components=1 -xf /tmp/ffmpeg.tar.xz \
    && rm /tmp/ffmpeg.tar.xz \
    && LD_LIBRARY_PATH=/opt/ffmpeg/lib /opt/ffmpeg/bin/ffmpeg -version

ENV PATH="/opt/ffmpeg/bin:$PATH" \
    LD_LIBRARY_PATH="/opt/ffmpeg/lib:$LD_LIBRARY_PATH"

# ---- TorchCodec 0.9 (native: our FFmpeg + patchelf RPATH, no patch-torchcodec) ----
# Use pip show Location so we patch the exact dir where pip installed (DLC can have
# site.getsitepackages() != pip install location).
RUN pip install --no-cache-dir "torchcodec==0.9.*" --index-url https://download.pytorch.org/whl/cu130 \
    && TORCH_LIB="$(python -c "import torch; print(torch.__path__[0])")/lib" \
    && TC_DIR="$(pip show -f torchcodec | sed -n 's/^Location: //p')/torchcodec" \
    && for so in "${TC_DIR}"/libtorchcodec_*.so; do \
         patchelf --add-rpath "/opt/ffmpeg/lib:${TORCH_LIB}" "$so"; \
       done

RUN python -c "import torch; from torchcodec.decoders import VideoDecoder; print('torch', torch.__version__, 'torchcodec OK')"
