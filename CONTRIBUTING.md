# Contributing to TelepromptMe

Thanks for taking an interest in TelepromptMe. The project is under active development, so focused changes that preserve the existing architecture are easiest to review.

## Before you start

- Use an issue to report bugs or propose substantial changes.
- Keep pull requests small and scoped to one concern.
- Do not commit generated build output, downloaded speech models, credentials, or Xcode user data.

## Development setup

1. Install Xcode 26 or later and CMake.
2. Run `./scripts/build-whisper-cpp.sh` from the repository root.
3. Open `TelepromptMe.xcodeproj` and use the `TelepromptMe` scheme.

## Verification

Build the app and run the test suite before opening a pull request:

```bash
xcodebuild -project TelepromptMe.xcodeproj -scheme TelepromptMe -configuration Debug build
xcodebuild -project TelepromptMe.xcodeproj -scheme TelepromptMe -configuration Debug test
```

Please mention any test you could not run and why.

