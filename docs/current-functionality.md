# Current Functionality

This document describes the functionality currently implemented in TelepromptMe.

## Script Library

- Stores scripts locally with SwiftData.
- Shows all scripts, favorite scripts, and scripts grouped by user-created collections.
- Supports creating, renaming, and deleting collections.
- Supports creating, editing, deleting, and favoriting scripts.
- Autosaves script title and body changes while editing.
- Tracks script word count, character count, and last-updated time in the editor.
- Opens the selected script in the teleprompter overlay from the library.
- Supports Apple Intelligence Writing Tools in the script editor on supported macOS versions.

## Teleprompter Overlay

- Presents a floating macOS overlay panel that can appear across spaces and fullscreen apps.
- Positions the overlay near the top center of the primary display, under the camera area.
- Shows the active script title, playback speed, and voice-follow status.
- Displays the active script in a clipped scrolling viewport.
- Provides overlay controls for play or pause, restart from top, voice follow, and hide.
- Applies user-configurable font, font size, line spacing, and overlay opacity.
- Updates overlay content when the active script changes.

## Playback

- Scrolls the active script automatically at a configurable words-per-minute speed.
- Supports play, pause, stop, restart from top, step forward, and step backward.
- Supports temporary hold-to-scroll behavior while the overlay is visible.
- Keeps playback within the measured script content bounds.
- Smoothly advances the overlay to a matched script position during voice follow.

## Voice Follow

- Can listen to the user's speech and advance the teleprompter based on matched script progress.
- Pauses normal auto-scroll when voice follow starts.
- Uses configurable matching sensitivity.
- Shows voice-follow states in the overlay: listening, following, finding place, or failure.
- Falls back to the built-in Apple Speech recognizer when a selected local model is unavailable.
- Can optionally start voice follow automatically when the overlay opens.

## Speech Recognition Engines and Models

- Includes an Apple built-in speech recognition option.
- Includes a Whisper speech recognition path using a native whisper.cpp wrapper.
- Captures microphone audio with `AVAudioEngine`.
- Converts microphone buffers to 16 kHz mono floating-point PCM for Whisper transcription.
- Runs Whisper transcription in process through the whisper.cpp C API.
- Emits partial and final recognition results while listening.
- Maintains a runtime-oriented speech model catalog.
- Lists built-in, downloadable, and imported speech model descriptors.
- Refreshes downloadable whisper.cpp model metadata from Hugging Face when available.
- Supports downloading whisper.cpp model files with progress, cancellation, partial-file cleanup, and installation state tracking.
- Supports deleting installed downloadable models.
- Stores installed speech models and model manifests under the app's Application Support directory.
- Filters language choices when the selected model declares supported languages.

## Settings

- Provides settings sections for General, AI Models, Appearance, and Shortcuts.
- Configures autoplay speed.
- Configures Dock icon, menu bar item, and default overlay positioning preferences.
- Configures overlay typography and opacity.
- Configures speech recognition engine, language, automatic voice follow, and matching sensitivity.
- Shows available speech models with installed, downloading, failed, custom, and recommended states.
- Allows model download, cancellation, deletion, and selection.
- Allows global keyboard shortcuts to be edited or cleared.

## Global Shortcuts

- Registers configurable global shortcuts for overlay and playback control.
- Supports shortcut commands for showing or hiding the overlay, toggling playback, hold-to-scroll, stopping, restarting, increasing speed, decreasing speed, stepping forward, and stepping backward.
- Supports modifier-only shortcuts for hold-to-scroll.

## Packaging and Distribution

- Includes a macOS packaging script.
- Includes a whisper.cpp build script that creates an Apple Silicon macOS XCFramework with Metal support.
- Links the native whisper.cpp framework into the app target.

## Tests

- Covers speech model catalog behavior.
- Covers speech recognition engine factory routing.
- Covers Whisper transcriber behavior.
