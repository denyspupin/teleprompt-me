# Third-Party Speech Model Support Plan

TelepromptMe should support third-party local speech models without committing to
Core ML as the primary runtime. The first implementation target is
Whisper-compatible local models via whisper.cpp.

## Direction

- Keep Apple Speech as the built-in fallback.
- Add a runtime-oriented speech model catalog.
- Start with whisper.cpp models and custom Whisper model import.
- Avoid Core ML-specific model contracts unless a later runtime needs them.
- Borrow Handy's model lifecycle discipline: rich metadata, cancellable downloads,
  checksum verification, custom model discovery, one loaded runtime, and language
  validation before transcription.

## Model Storage

Store local models under:

```text
Application Support/TelepromptMe/SpeechModels/
  catalog.json
  whisper-small/
    ggml-small.bin
    model.json
  custom-my-model/
    custom-model.bin
    model.json
```

Each `model.json` should describe the runtime, architecture, display metadata,
expected model file, checksum when known, size, supported languages, and whether
the model is custom or recommended.

## Runtime Shape

Use runtime-oriented metadata instead of hard-coding every model as an enum case:

```swift
enum SpeechRecognitionRuntime: String, Codable {
    case appleSpeech
    case whisperCpp
    case whisperKit
    case externalProcess
}

enum SpeechRecognitionArchitecture: String, Codable {
    case appleBuiltIn
    case whisper
}
```

The first local runtime should be `whisperCpp`.

## Implementation Phases

### Completed

1. Save the Whisper-first implementation plan.
   - Documented the decision to avoid a Core ML-first model path.
   - Kept Apple Speech as the fallback runtime.
   - Chose whisper.cpp as the first third-party local runtime.

2. Add the native whisper.cpp Swift wrapper.
   - Added `WhisperCppTranscriber`.
   - Replaced the `whisper-cli` process wrapper with an actor-isolated wrapper
     around the whisper.cpp C API.
   - Loads the selected `ggml-*.bin` model with
     `whisper_init_from_file_with_params`.
   - Runs transcription in process with `whisper_full`.
   - Keeps language, translation, timestamp, context, and single-segment options
     in Swift.

3. Bundle the whisper.cpp native framework.
   - Added `scripts/build-whisper-cpp.sh`.
   - Pinned whisper.cpp to commit `99613cb720b65036237d44b52f753b51f75c2797`.
   - Builds `Vendor/whisper.cpp/build-apple/whisper.xcframework` with Metal
     support.
   - Builds only the `macos-arm64` XCFramework slice for Apple Silicon and
     macOS 26.0 or later.
   - Links and embeds `whisper.xcframework` in the app target.
   - Removed the `Copy Whisper Runtime` build phase and CLI/dylib resource
     bundling.
   - Keeps `Vendor/whisper.cpp/` out of git.

4. Prove native transcription end to end.
   - Installed `ggml-tiny.en.bin` locally for the first smoke test.
   - Used `Vendor/whisper.cpp/samples/jfk.wav` as the tiny WAV fixture.
   - The native runtime now consumes in-memory 16 kHz mono float samples instead
     of shelling out to a file-level CLI.

5. Add `WhisperSpeechRecognitionEngine`.
   - Conform to `SpeechRecognitionEngine`.
   - Request microphone permission.
   - Capture audio with `AVAudioEngine`.
   - Convert microphone buffers to 16 kHz mono float PCM in memory.
   - Feed a rolling sample window to the native `WhisperCppTranscriber`.
   - Emit partial `SpeechRecognitionResult` values while recording.
   - Emit a final `SpeechRecognitionResult` on stop.

6. Add a speech engine factory.
   - Keep `SpeechFollowController` independent from concrete runtimes.
   - Route Apple models to `AppleSpeechRecognitionEngine`.
   - Route Whisper models to `WhisperSpeechRecognitionEngine`.
   - Keep Apple Speech as fallback if the Whisper model is missing.

7. Add `SpeechModelCatalog`.
   - Built-in Apple Speech descriptor.
   - Downloadable Whisper descriptors.
   - Custom/imported descriptors.
   - Selected-model fallback when a selected model disappears.

8. Upgrade download lifecycle.
   - Byte-level progress.
   - Cancellation.
   - `.partial` files.
   - SHA256 verification.
   - Cleanup of interrupted downloads.
   - Delete/unload behavior for active models.

9. Add custom model import.
   - Start with user-selected Whisper model files (`.bin`, later `.gguf` if the
     chosen whisper.cpp build supports it).
   - Generate local metadata.
   - Validate file existence and basic compatibility before selection.

10. Update Settings UI.
   - Show installed/downloading/incompatible states.
   - Show model size, language support, custom/recommended badges.
   - Provide download/cancel/delete/select/import actions.
   - Filter or reset language selection based on selected model support.

11. Add focused tests.
   - Catalog decoding/discovery.
   - Download state transitions.
   - SHA256 mismatch handling.
   - Selection fallback.
   - Engine factory routing.
   - Whisper wrapper command construction.
   - Bundled runtime resolution.
   - File-level Whisper transcription using a fixture.

### Next

No planned implementation tasks remain in this phase.

## Notes From Handy

The best Handy patterns to keep are:

- typed model capabilities instead of plain names
- resumable/cancellable download state
- checksum verification
- custom model discovery
- one active loaded model
- language validation before transcription
- clear model state events for the UI

The Handy-specific multi-engine Rust backend is useful as inspiration, but
TelepromptMe should stay Swift-native and start with a narrow Whisper runtime.
