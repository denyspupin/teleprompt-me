# Current Functionality

TelepromptMe v1 is a focused, local macOS teleprompter.

## Script Library

- Stores scripts locally with SwiftData.
- Shows all scripts, favorites, and user-created collections.
- Creates and edits script titles and bodies.
- Autosaves edits and surfaces save failures.
- Confirms script deletion.
- Creates and renames collections.
- Confirms collection deletion and preserves its scripts in All Scripts.
- Tracks word count, character count, and last-updated time.
- Opens the selected script in the teleprompter overlay.
- Supports Writing Tools on supported macOS versions.

## Teleprompter Overlay

- Presents a floating panel across Spaces and full-screen applications.
- Positions the overlay below the camera area on the primary display.
- Displays the active script in a clipped scrolling viewport.
- Provides play or pause, restart, and hide controls.
- Applies the configured font, font size, line spacing, and opacity.

## Autoplay

- Scrolls at a configurable words-per-minute speed.
- Supports play, pause, stop, and restart from the top.
- Clamps speed and scroll position to supported bounds.
- Stops cleanly at the end of the script.

## Settings

- Configures autoplay speed.
- Configures font family, font size, line spacing, and overlay opacity.
- Every visible setting has an implemented effect.

## Keyboard Control

- Registers global shortcuts for showing or hiding the overlay, toggling playback, and restarting.
- Allows each v1 shortcut to be edited or cleared and applies changes immediately.
- Prevents the same shortcut from being assigned to more than one action.
- Keeps equivalent overlay controls and application menu commands available.

## Packaging and Distribution

- Targets macOS 26 or later on Apple Silicon.
- Builds without a generated or vendored speech-recognition framework.
- Supports unsigned tester packages and Developer ID distribution.
- Supports notarization and stapling.

## Tests

- Covers autoplay state and speed behavior.
- Covers script persistence and deletion.
- Covers non-destructive collection deletion.
- Covers shortcut defaults, customization, clearing, and persistence.
