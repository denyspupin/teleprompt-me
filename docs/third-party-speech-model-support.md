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

1. Add `SpeechModelCatalog`.
   - Built-in Apple Speech descriptor.
   - Downloadable Whisper descriptors.
   - Custom/imported descriptors.
   - Selected-model fallback when a selected model disappears.

2. Upgrade download lifecycle.
   - Byte-level progress.
   - Cancellation.
   - `.partial` files.
   - SHA256 verification.
   - Cleanup of interrupted downloads.
   - Delete/unload behavior for active models.

3. Add a speech engine factory.
   - Keep `SpeechFollowController` independent from concrete runtimes.
   - Route Apple models to `AppleSpeechRecognitionEngine`.
   - Route Whisper models to the whisper.cpp-backed engine.

4. Add the whisper.cpp wrapper.
   - Start with a Swift process wrapper around a bundled `whisper-cli` executable.
   - Accept a model URL, WAV input URL, language, and translation flag.
   - Return a final transcript.
   - Later replace or supplement with direct C/C++ library binding if needed.

5. Add custom model import.
   - Start with user-selected Whisper model files (`.bin`, later `.gguf` if the
     chosen whisper.cpp build supports it).
   - Generate local metadata.
   - Validate file existence and basic compatibility before selection.

6. Update Settings UI.
   - Show installed/downloading/incompatible states.
   - Show model size, language support, custom/recommended badges.
   - Provide download/cancel/delete/select/import actions.
   - Filter or reset language selection based on selected model support.

7. Add focused tests.
   - Catalog decoding/discovery.
   - Download state transitions.
   - SHA256 mismatch handling.
   - Selection fallback.
   - Engine factory routing.
   - Whisper wrapper command construction.

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
