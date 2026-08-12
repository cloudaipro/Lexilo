# Lexilo neural voice pack

Lexilo bundles the English `kitten-nano-en-v0_2-fp16` model and executes it fully
on-device with sherpa-onnx. No text, waveform, or learner data is sent to a
speech service.

## Pinned artifacts

- sherpa-onnx v1.13.2 iOS archive
  - Source: https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.13.2
  - SHA-256: `2886a04df4f8d5066c6c8b6e712278d65d7b60fc9e45990223df50262861d38b`
- kitten-nano-en-v0_2-fp16
  - Documentation: https://k2-fsa.github.io/sherpa/onnx/tts/all/English/kitten-nano-en-v0_2.html
  - Archive SHA-256: `0345a8a2f4a710cb8f7912c9a731ded8b3e1e69b33a871efa95c2e64651518fe`
  - model.fp16.onnx SHA-256: `f24264d818087e643828da7a992e892e703c412bf147e152b825da567031d5ce`
  - voices.bin SHA-256: `42a40a24a352a38657d6cb86ceee51bbc2b7780b29e04fb60bcdf959adccea01`
  - tokens.txt SHA-256: `934a4188addc7665dd3410256bb622169242357fbb99d840d9351209b486dabb`
- ONNX Runtime 1.17.1, supplied by the pinned sherpa-onnx iOS archive.

The corresponding Apache-2.0 licenses and ONNX Runtime third-party notices are
included in the application resources. The Kitten model's Apache-2.0 license is
also inside `KittenVoice.bundle` and at `Resources/Kitten/LICENSE-Kitten.txt`.
