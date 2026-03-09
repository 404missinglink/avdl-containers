#!/usr/bin/env bash
# Run inside the built image to verify PyTorch + TorchCodec.
# Usage: ./verify-torchcodec.sh   (after: docker build -t pytorch-torchcodec-vision:latest .)
set -e
docker run --rm pytorch-torchcodec-vision:latest python -c "
import torch
from torchcodec.decoders import VideoDecoder
print('PyTorch:', torch.__version__)
print('TorchCodec VideoDecoder:', VideoDecoder)
print('OK')
"
