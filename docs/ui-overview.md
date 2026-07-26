# TelepromptMe v1 UI Overview

## Product flow

TelepromptMe has four user-facing surfaces:

1. **Script Library** — browse all scripts, favorites, and collections.
2. **Script Editor** — write and revise a script with automatic saving.
3. **Teleprompter Overlay** — present the active script using autoplay or Voice Follow.
4. **Settings** — configure reading behavior, appearance, and global shortcuts.

The intended v1 journey is:

`Choose or create a script → edit it → present it → control the overlay`

## Review findings

### What was already working

- The main window used a familiar sidebar-and-detail structure.
- Library, editor, settings, and overlay features were all discoverable.
- The interface used native SwiftUI controls and SF Symbols.
- Empty-library messaging, destructive confirmations, and accessibility labels were present.
- Light and dark system appearances were supported at the platform level.

### Issues found

- Script cards exposed four equally prominent actions, which made the primary task unclear.
- Several surfaces used hard-coded white transparency. This looked acceptable in Dark Mode but produced inconsistent contrast in Light Mode.
- Settings appeared both inside the main window and in a separate Settings window.
- Settings used large custom cards instead of the native macOS settings hierarchy.
- The script editor emphasized Writing Tools and deletion but did not offer a clear primary action for presenting the script.
- The overlay applied translucent styling to the entire content layer and then used additional custom translucent controls, reducing visual hierarchy.
- Custom sidebar selection and hover treatments duplicated behavior already provided by macOS.
- Rounded display typography was used for ordinary window titles, making the app feel less consistent with standard Mac productivity apps.

## Implemented v1 design

### Script Library

- Uses a native macOS sidebar list with system selection, sizing, accent color, and accessibility behavior.
- Keeps All Scripts, Favorites, and user collections in a shallow hierarchy.
- Places New Script and overlay visibility in the window toolbar as frequent commands.
- Shows the number of scripts in the current section.
- Uses semantic system surfaces and separators so cards remain legible in Light Mode, Dark Mode, increased contrast, and reduced transparency.
- Makes **Present** the single visible row action.
- Moves edit, favorite, and delete into a standard More menu and context menu.
- Marks the active teleprompter script without relying on color alone.
- Keeps double-click-to-edit for a familiar Mac workflow.

### Script Editor

- Uses a clear document hierarchy: navigation, title, metadata, editor, save status.
- Adds **Present Script** as the primary action.
- Moves deletion into a secondary menu.
- Keeps Writing Tools available without making them the main workflow.
- Uses a semantic text background and separator around the editing surface.
- Shows an explicit automatic-save status.

### Teleprompter Overlay

- Uses a standard material for the content panel and reserves Liquid Glass for interactive controls.
- Groups playback, restart, Voice Follow, and hide controls consistently.
- Gives Play/Pause the strongest visual emphasis.
- Shows speed and Voice Follow state with symbols and text.
- Keeps speech errors visible without changing the reading content.

### Settings

- Uses the standard macOS Settings scene opened from the app menu or Command–Comma.
- Uses a stable tab for each category: General, Appearance, and Keyboard Shortcuts.
- Uses native forms, sections, toggles, pickers, sliders, and footers.
- Removes the duplicate settings area from the library sidebar.
- Explains on-device Voice Follow beside its controls.

## Design rules for v1

- Prefer native macOS navigation, menus, controls, typography, and semantic colors.
- Reserve Liquid Glass for navigation and high-value interactive controls, not content cards.
- Present one primary action for each context.
- Put infrequent or destructive actions in menus.
- Respect the system accent color, appearance, contrast, and transparency preferences.
- Keep labels visible for critical actions; icon-only controls must include help and accessibility labels.
- Keep the sidebar hierarchy to two levels.
- Keep all toolbar actions available through the menu bar or another visible interface.
- Avoid adding visual customization that does not improve reading or presenting.

## Acceptance criteria

- The library, editor, overlay, and settings remain usable in Light and Dark Mode.
- Every essential action has a text label, Help description, or accessibility label.
- New Script, Present Script, Show/Hide Overlay, autoplay, Voice Follow, restart, and deletion remain discoverable.
- Settings are available through the standard macOS Settings command.
- The app builds and all automated tests pass after the UI refresh.
