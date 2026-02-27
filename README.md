# AI Video Caption Editor (macOS, SwiftUI)

Native macOS caption editor optimized for Apple Silicon with local-first transcription and GPU render paths.

## Stack
- SwiftUI + AppKit
- AVFoundation / AVPlayer
- whisper.cpp (via local `whisper-cli`)
- Metal + Core Image for GPU-backed caption compositing
- AVAssetExportSession export pipeline

## Project Layout
- `Sources/AIVideoCaptionEditor/App` app entry + root layout
- `Sources/AIVideoCaptionEditor/Models` caption/style model layer
- `Sources/AIVideoCaptionEditor/Managers` video, audio extraction, transcription
- `Sources/AIVideoCaptionEditor/Controllers` timeline synchronization
- `Sources/AIVideoCaptionEditor/Rendering` caption animation + Metal overlay renderer
- `Sources/AIVideoCaptionEditor/Lyrics` lyric segmentation/alignment engine
- `Sources/AIVideoCaptionEditor/Styling` preset + style manager
- `Sources/AIVideoCaptionEditor/Export` GPU export manager
- `Sources/AIVideoCaptionEditor/Views` player/editor/timeline UI
- `Sources/AIVideoCaptionEditor/ViewModels` editor state orchestration

## whisper.cpp Setup (Offline)
1. Build whisper.cpp with Metal:
```bash
git clone https://github.com/ggerganov/whisper.cpp ThirdParty/whisper.cpp
cmake -S ThirdParty/whisper.cpp -B ThirdParty/whisper.cpp/build -DGGML_METAL=ON
cmake --build ThirdParty/whisper.cpp/build --config Release
```
2. Put a model at one of:
- `./Models/ggml-base.en.bin`
- `./Models/ggml-small.en.bin`
- `./ThirdParty/whisper.cpp/models/ggml-base.en.bin`

The app auto-detects `whisper-cli` from:
- `./ThirdParty/whisper.cpp/build/bin/whisper-cli`
- `/opt/homebrew/bin/whisper-cli`
- `/usr/local/bin/whisper-cli`

## Build
```bash
swift build
swift run
```

Open this folder in Xcode to run as a native macOS app.
