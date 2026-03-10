# DLC PyTorch 2.9, Python 3.12, CUDA 13.0
#
# Build order: BtbN FFmpeg 8 (known-good) + manual patchelf on TorchCodec .so.
# patch-torchcodec (PyAV) fails in DLC (verify fails; likely PyAV FFmpeg vs cu130 wheel mismatch).
#
#   1. Base: DLC has torch (GPU), long LD_LIBRARY_PATH.
#   2. apt: curl, patchelf, xz-utils (for BtbN tarball).
#   3. BtbN FFmpeg 8 shared -> /opt/ffmpeg; ENV PATH and LD_LIBRARY_PATH.
#   4. pip install torchcodec (cu130 to match DLC torch); patchelf .so RPATH to /opt/ffmpeg/lib + torch lib.
#   5. Verify with LD_LIBRARY_PATH set in same RUN so loader sees our libs first.
#
FROM public.ecr.aws/deep-learning-containers/pytorch-training:2.9.0-gpu-py312-cu130-ubuntu22.04-ec2

USER root

# 2. patchelf + deps for BtbN tarball
RUN for i in 1 2 3; do apt-get update && break || { [ "$i" -eq 3 ] && exit 1; sleep 10; }; done \
    && apt-get install -y --no-install-recommends curl patchelf xz-utils \
    && rm -rf /var/lib/apt/lists/*

# 3. BtbN FFmpeg 8 shared -> /opt/ffmpeg
ARG BTBN_FFMPEG_URL="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n8.0-latest-linux64-gpl-shared-8.0.tar.xz"
RUN curl -sL -o /tmp/ffmpeg.tar.xz "${BTBN_FFMPEG_URL}" \
    && mkdir -p /opt/ffmpeg \
    && tar -C /opt/ffmpeg --strip-components=1 -xf /tmp/ffmpeg.tar.xz \
    && rm /tmp/ffmpeg.tar.xz \
    && LD_LIBRARY_PATH=/opt/ffmpeg/lib /opt/ffmpeg/bin/ffmpeg -version

ENV PATH="/opt/ffmpeg/bin:$PATH" \
    LD_LIBRARY_PATH="/opt/ffmpeg/lib:/usr/local/lib/python3.12/site-packages/torch/lib:$LD_LIBRARY_PATH"

# Debug: show final LD_LIBRARY_PATH as seen in this image
RUN echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"

# 4. TorchCodec (cu130) + patchelf RPATH so .so finds /opt/ffmpeg/lib and torch lib
RUN pip install --no-cache-dir "torchcodec==0.9.*" --index-url https://download.pytorch.org/whl/cu130 \
    && TORCH_LIB="$(python -c "import torch; print(torch.__path__[0])")/lib" \
    && TC_DIR="$(pip show -f torchcodec | sed -n 's/^Location: //p')/torchcodec" \
    && for so in "${TC_DIR}"/libtorchcodec_*.so; do [ -f "$so" ] && patchelf --add-rpath "/opt/ffmpeg/lib:${TORCH_LIB}" "$so"; done

# 5. Verify (export in same RUN so DLC loader sees our libs first)
RUN export LD_LIBRARY_PATH="/opt/ffmpeg/lib:/usr/local/lib/python3.12/site-packages/torch/lib:${LD_LIBRARY_PATH:-}" \
    && python -c "import torch; from torchcodec.decoders import VideoDecoder; print('torch', torch.__version__, 'torchcodec OK')"
