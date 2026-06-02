# AGENTS.md

TelepromptMe is a Swift project targeting macOS 26 and later.

## Project Notes

- Use the existing SwiftUI and Xcode project structure.
- Keep changes focused and avoid broad refactors unless they are required for the task.
- Prefer existing app models, services, and feature folders before adding new abstractions.

## Workflow

- After any code or project change, build the project to verify it still works:
  `xcodebuild -project TelepromptMe.xcodeproj -scheme TelepromptMe -configuration Debug build`
- Develop each new feature on a separate branch named `feature/<feature-name>`.
- When a feature is done, create a pull request from the feature branch into `main`.
