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

2. Add the initial whisper.cpp Swift wrapper.
   - Added `WhisperCppTranscriber`.
   - Wrapped `whisper-cli` through `Process`.
   - Added validation for executable, model, and audio file paths.
   - Added cancellation handling.
   - Added bundled executable resolution through
     `WhisperCppTranscriber.bundledExecutableURL`.

3. Bundle the whisper.cpp runtime.
   - Added `scripts/build-whisper-cpp.sh`.
   - Pinned whisper.cpp to commit `99613cb720b65036237d44b52f753b51f75c2797`.
   - Builds `whisper-cli` with Metal support.
   - Added `scripts/copy-whisper-runtime.sh`.
   - Added the Xcode `Copy Whisper Runtime` build phase.
   - Copies `whisper-cli` and required `libwhisper`/`libggml` dylibs into
     `Contents/Resources/whisper`.
   - Rewrites the runtime rpath to load dylibs from the bundled folder.
   - Keeps `Vendor/whisper.cpp/` out of git.

### Next

1. Prove file-level transcription end to end.
   - Download or install a small known Whisper model, preferably
     `ggml-base.en.bin` for the first smoke test.
   - Add or identify a tiny WAV fixture.
   - Run `WhisperCppTranscriber` against the bundled `whisper-cli`, local model,
     and WAV file.
   - Confirm whether `--output-txt` writes to stdout or a sidecar file for the
     current pinned CLI.
   - Adjust `WhisperCppTranscriber` output parsing so it reliably returns the
     final transcript.

2. Add `WhisperSpeechRecognitionEngine`.
   - Conform to `SpeechRecognitionEngine`.
   - Request microphone permission.
   - Capture audio with `AVAudioEngine`.
   - Write session audio to a temporary 16-bit WAV file.
   - Invoke `WhisperCppTranscriber`.
   - Emit a final `SpeechRecognitionResult`.
   - Keep partial/streaming transcription for a later iteration.

3. Add a speech engine factory.
   - Keep `SpeechFollowController` independent from concrete runtimes.
   - Route Apple models to `AppleSpeechRecognitionEngine`.
   - Route Whisper models to `WhisperSpeechRecognitionEngine`.
   - Keep Apple Speech as fallback if the Whisper runtime or model is missing.

4. Add `SpeechModelCatalog`.
   - Built-in Apple Speech descriptor.
   - Downloadable Whisper descriptors.
   - Custom/imported descriptors.
   - Selected-model fallback when a selected model disappears.

5. Upgrade download lifecycle.
   - Byte-level progress.
   - Cancellation.
   - `.partial` files.
   - SHA256 verification.
   - Cleanup of interrupted downloads.
   - Delete/unload behavior for active models.

6. Add custom model import.
   - Start with user-selected Whisper model files (`.bin`, later `.gguf` if the
     chosen whisper.cpp build supports it).
   - Generate local metadata.
   - Validate file existence and basic compatibility before selection.

7. Update Settings UI.
   - Show installed/downloading/incompatible states.
   - Show model size, language support, custom/recommended badges.
   - Provide download/cancel/delete/select/import actions.
   - Filter or reset language selection based on selected model support.

8. Add focused tests.
   - Catalog decoding/discovery.
   - Download state transitions.
   - SHA256 mismatch handling.
   - Selection fallback.
   - Engine factory routing.
   - Whisper wrapper command construction.
   - Bundled runtime resolution.
   - File-level Whisper transcription using a fixture.

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
