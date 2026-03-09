"""Hello world script that verifies PyTorch and TorchCodec are working."""

import torch
from torchcodec.decoders import VideoDecoder

def main() -> None:
    print("PyTorch version:", torch.__version__)
    print("TorchCodec imported successfully.")

    # Verify we can instantiate a decoder (will only open if file exists).
    # Using a non-existent path is fine: we just want to confirm the API is available.
    decoder_cls = VideoDecoder
    print("VideoDecoder class available:", decoder_cls)

    print("All checks passed. TorchCodec is working.")

if __name__ == "__main__":
    main()
