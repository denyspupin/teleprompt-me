# TelepromptMe

TelepromptMe is a native macOS teleprompter built for people who speak to a camera. It keeps a script in a compact floating overlay near the camera and can follow along as you speak using on-device speech recognition.

> [!IMPORTANT]
> TelepromptMe is an early work in progress. The core workflow is usable, but the app is not yet ready for general distribution and interfaces may change without notice.

## What works today

- Create, edit, organize, favorite, and locally persist scripts.
- Open a script in a floating overlay that stays available across spaces and fullscreen apps.
- Play, pause, restart, and adjust automatic scrolling by words per minute.
- Follow spoken progress with Apple Speech or a downloadable whisper.cpp model.
- Customize overlay typography, line spacing, opacity, and global keyboard shortcuts.
- Download and manage supported Whisper models from within the app.

For a more detailed implementation inventory, see [Current Functionality](docs/current-functionality.md).

## Project status

The current focus is making speech-following faster and more reliable. In particular, matching spoken phrases back to the script, model lifecycle UX, first-run guidance, and distribution still need more work.

This repository is public as a build-in-public project: it shows the real implementation and its progress, not a finished product. Bug reports and thoughtful feedback are welcome, but there are currently no prebuilt releases or support guarantees.

## Requirements

- An Apple silicon Mac
- macOS 26 or later
- Xcode 26 or later
- CMake (required once to build the native whisper.cpp dependency)

## Build from source

The generated whisper.cpp XCFramework is intentionally not committed. Build it before opening or compiling the app for the first time:

```bash
git clone https://github.com/denyspupin/teleprompt-me.git
cd teleprompt-me
./scripts/build-whisper-cpp.sh
open TelepromptMe.xcodeproj
```

Then select the `TelepromptMe` scheme in Xcode and run the app. You can also build from the command line:

```bash
xcodebuild -project TelepromptMe.xcodeproj \
  -scheme TelepromptMe \
  -configuration Debug \
  build
```

The dependency build downloads a pinned revision of [whisper.cpp](https://github.com/ggml-org/whisper.cpp) and creates an Apple silicon XCFramework under the ignored `Vendor/` directory.

## Privacy

Scripts and settings are stored locally. Speech audio is processed through the selected recognition engine; TelepromptMe supports Apple's built-in speech recognizer and local whisper.cpp models. The app requests microphone and speech-recognition permissions for voice follow, and network access is used to discover and download optional model files.

## Repository guide

- `TelepromptMe/App` — app lifecycle and shared state
- `TelepromptMe/Core` — persisted and domain models
- `TelepromptMe/Features` — library, editor, overlay, and settings UI
- `TelepromptMe/Shared/Services` — playback, persistence, shortcuts, and speech recognition
- `TelepromptMeTests` — model catalog, engine routing, and transcription tests
- `docs` — current capability and distribution notes
- `scripts` — native dependency and packaging automation

## Contributing

TelepromptMe is currently a personal, in-progress project, but focused bug reports and small pull requests are welcome. Please open an issue before investing in a large change so the direction can be discussed first. See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow.

## License

No open-source license has been selected yet. The source is public for transparency and learning, but no permission to copy, modify, or redistribute it is granted at this time.

