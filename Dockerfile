# DLC PyTorch 2.9, Python 3.12, CUDA 13.0
FROM public.ecr.aws/deep-learning-containers/pytorch-training:2.9.0-gpu-py312-cu130-ubuntu22.04-ec2

USER root

# patch-torchcodec runs patchelf; need it on PATH.
RUN for i in 1 2 3; do apt-get update && break || { [ "$i" -eq 3 ] && exit 1; sleep 10; }; done \
    && apt-get install -y --no-install-recommends patchelf \
    && rm -rf /var/lib/apt/lists/*

# TorchCodec 0.9 (CPU wheel; patch-torchcodec works with PyAV) + PyAV + patch-torchcodec
RUN pip install --no-cache-dir "torchcodec==0.9.*" --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir av patch-torchcodec \
    && patch-torchcodec

RUN patch-torchcodec --verify
