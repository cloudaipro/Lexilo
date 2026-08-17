# Offline pronunciation decision

Checked: 2026-08-15

## Implemented decision

Lexilo bundles `kitten-nano-en-v0_2-fp16` and runs it with sherpa-onnx v1.13.2 for every word. Apple's `AVSpeechSynthesizer` is retained only as the automatic runtime failure fallback. All synthesis is local.

The app exposes all 8 Kitten voices, a 0.7–1.2× speech-rate control, cancellation, serialized background inference, and WAV playback through `AVAudioPlayer`. It initializes the model after launch and pre-generates the Today word plus the current/next practice words into a bounded 96-item memory and 192-file disk cache. Cache keys include model version, normalized word, voice, and rate. The model and runtime are pinned by SHA-256 and their licenses are bundled.

On the iPhone 17 Pro simulator, a direct same-runtime test of “resilient” measured about 0.99 seconds cold and 0.37 seconds warm for Kitten, compared with 2.91 seconds cold and 1.69 seconds warm for the former Kokoro int8 pack. Cached playback avoids inference entirely. Device performance remains a release gate.

## Neural candidates researched

| Candidate | Fit for Lexilo | Main tradeoff |
| --- | --- | --- |
| sherpa-onnx + Kitten Nano v0.2 | **Selected and implemented.** Apache-2.0, eight English voices, documented Swift/iOS support, a roughly 23 MB model, and materially faster local measurements. | FP16 performance and memory still need validation on the oldest supported iPhone. |
| sherpa-onnx + quantized Kokoro-82M | High voice quality and mature sherpa support. | The tested pack was roughly 128 MB and materially slower for Lexilo's short single-word utterances. |
| Supertonic 3 via sherpa-onnx | Strong multilingual option with an int8 path and Swift API. | OpenRAIL-M usage restrictions require a product-policy review; unnecessary for English-only V1. |
| Pocket TTS | Attractive streaming latency and a 100M model. | Gated CC BY terms, voice-cloning surface, and a less mature mobile deployment story. |
| MOSS-TTS-Nano | Capable 100M multilingual research model with ONNX and MLX exports. | The MLX weights alone are about 285 MB and synthesis also needs its audio tokenizer/decoder. The official mobile path is presently Android-oriented; a maintained Nano-specific Swift/iOS integration is not yet demonstrated. |
| mlx-audio / mlx-audio-swift | Useful reference implementations and rapidly improving MLX inference support. | Python `mlx-audio` is not an iOS runtime. The Swift project is young, uses main-branch dependencies, and does not remove the MOSS model/decoder footprint. It is therefore not the production choice by itself. |

## Remaining release-performance gate

The integration is functionally verified by a real model-inference test. Before an App Store release, benchmark the production build on the oldest supported iPhone to verify:

1. iPhone deployment and App Store-compatible dependencies.
2. Offline cold start, first-audio latency, real-time factor, peak resident memory, and thermal behavior on the oldest supported iPhone.
3. Word-level intelligibility across heteronyms, inflections, abbreviations, and uncommon Simple English Wiktionary learning terms.
4. A/B listener preference against installed iOS enhanced voices.
5. Model and voice licensing, attribution, safety terms, and update strategy.

## Primary references

- Apple AVSpeechSynthesizer: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer
- sherpa-onnx and Swift/iOS build guide: https://github.com/k2-fsa/sherpa-onnx and https://k2-fsa.github.io/sherpa/onnx/ios/build-sherpa-onnx-swift.html
- Kitten Nano packaging and voices: https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kitten.html and https://k2-fsa.github.io/sherpa/onnx/tts/all/English/kitten-nano-en-v0_2.html
- Kokoro comparison: https://huggingface.co/hexgrad/Kokoro-82M and https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html
- Supertonic 3: https://huggingface.co/Supertone/supertonic-3
- Pocket TTS: https://huggingface.co/kyutai/pocket-tts
- MOSS-TTS-Nano and ONNX export: https://github.com/OpenMOSS/MOSS-TTS-Nano and https://huggingface.co/OpenMOSS-Team/MOSS-TTS-Nano-100M-ONNX
- MLX MOSS conversion supplied for evaluation: https://huggingface.co/mlx-community/MOSS-TTS-Nano-100M/tree/main
- MLX Swift and mlx-audio-swift: https://github.com/ml-explore/mlx-swift and https://github.com/Blaizzy/mlx-audio-swift
