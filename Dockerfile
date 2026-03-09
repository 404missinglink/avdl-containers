# DLC PyTorch 2.9, Python 3.12, CUDA 13.0
FROM public.ecr.aws/deep-learning-containers/pytorch-training:2.9.0-gpu-py312-cu130-ubuntu22.04-ec2

USER root

# ---- FFmpeg 8 (static, multi-stage) ----
COPY --from=mwader/static-ffmpeg:8.0.1 /ffmpeg /usr/local/bin/ffmpeg
COPY --from=mwader/static-ffmpeg:8.0.1 /ffprobe /usr/local/bin/ffprobe
RUN ffmpeg -version

# ---- TorchCodec (needs shared FFmpeg libs; static build has none, so use apt for libs) ----
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && ldconfig

RUN pip install --no-cache-dir "torchcodec==0.9.*" --index-url https://download.pytorch.org/whl/cu130

ENV LD_LIBRARY_PATH=/usr/local/lib/python3.12/site-packages/torchcodec:/usr/local/lib/python3.12/site-packages/torch/lib:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}
RUN python -c "import torch; from torchcodec.decoders import VideoDecoder; print('torch', torch.__version__, 'torchcodec OK')"
