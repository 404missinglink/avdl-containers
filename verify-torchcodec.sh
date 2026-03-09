#!/usr/bin/env bash
# Run inside the built image to verify PyTorch + TorchCodec.
# Usage: ./verify-torchcodec.sh   (after: docker build -t <tag> .)
set -e
docker run --rm "${1:-ghcr.io/404missinglink/avdl-containers:latest}" python -c "import torch; from torchcodec.decoders import VideoDecoder; print('PyTorch:', torch.__version__); print('TorchCodec OK')"
