# Mac keyboard and window cheatsheet

Notes for macOS and a Redragon K552-KR external keyboard.

## Modifier symbols

| Symbol | Key |
|---|---|
| ⌘ | Command; normally the Windows key on a PC keyboard |
| ⌥ | Option; normally Alt on a PC keyboard |
| ⌃ | Control |
| ⇧ | Shift |
| Globe / Fn | Apple's Fn modifier, distinct from the Redragon's hardware Fn key |

Modifier remapping changes these defaults. Check **System Settings → Keyboard → Keyboard Shortcuts → Modifier Keys** and select the external keyboard.

## Window arrangements

| Arrangement | Behavior |
|---|---|
| Ordinary windows | Freely movable, resizable, overlapping windows on a desktop |
| Desktop tiling | **Window → Move & Resize** places ordinary windows in halves or quarters on the same desktop |
| Fill | Enlarges a window to fill the desktop without entering full screen |
| Full screen | Places one window in its own workspace, called a Space |
| Split View | **Window → Full Screen Tile → Left/Right of Screen** creates a two-window pair in its own Space |

**For temporary side-by-side work, use Move & Resize.** Use Split View when you want a dedicated workspace for the pair.

### Leaving Split View

1. Reveal the window controls at the top and use the green-button menu's **Move Window to Desktop** action.
2. The other window remains **full screen in its own Space**.
3. Find it with **Control + ↑**, select it, then exit full screen with the green button or **Control + Command + F** in supporting apps.

**Return to Previous Size** undoes desktop tiling; it does not exit full screen.

### Switching around

| Action | Shortcut |
|---|---|
| Switch apps | Command + Tab |
| Cycle current app's windows | Command + backtick, ` |
| Mission Control | Control + ↑ |
| Current app's windows | Control + ↓ |
| Previous/next Space | Control + ← / → |
| Toggle full screen in many apps | Control + Command + F |
| Hide app | Command + H |
| Minimize window | Command + M |
| Close window or tab | Command + W |
| Quit app | Command + Q |

For predictable Space ordering, consider disabling **Automatically rearrange Spaces based on most recent use** under **Desktop & Dock → Mission Control**.

## Custom window shortcuts

Apple's default desktop-tiling shortcuts use **Globe/Fn + Control**. The Redragon's physical Fn key does not supply Apple's modifier, and this setup does not offer a Caps Lock → Globe mapping in macOS.

Use **System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts → +** instead. Select **All Applications**, enter the exact menu title, and record a shortcut.

Nested menu paths can disambiguate names:

```text
Window->Move & Resize->Left
Window->Move & Resize->Right
Window->Move & Resize->Fill
Window->Move & Resize->Center
```

Use the actual menu path for **Return to Previous Size**; its location can vary by app.

Current preference: **Control + Option** as the window-management prefix. Left/right arrows work for left/right tiling. Choose another key for Center: **Control + Option + C closed the shortcut-recording dialog on both the external and built-in keyboards**. The cause was not established.

### Shortcut conflicts

- **Control + Command + F** already toggles full screen. Assigning it to Fill caused full screen instead, despite the menu showing the custom binding.
- **Control + Command + Space** opens the character viewer.
- **Control + Command + Q** locks the Mac.
- **Control + Command + D** performs dictionary lookup in supporting apps.
- Editors and Finder use additional Control + Command combinations.
- **Control + Option** is VoiceOver's default modifier when VoiceOver is enabled.

Settings does not detect every app-level conflict. Test custom bindings in your usual apps. App Shortcuts override menu commands; they are not a universal window manager.

Full-screen shortcuts can generally be overridden through App Shortcuts using the exact **Enter Full Screen** and **Exit Full Screen** menu titles. Some apps handle them separately.

## Redragon keyboard notes

- **Fn + Windows toggles Windows-key lock / gaming mode.** This also disables that key's Command function on the Mac. Command + V then types plain `v`.
- The key with a menu/list symbol is the **Menu/Application key**, not Command.
- The physical **Fn** key controls the keyboard's firmware layer, including media, lighting, and key lock.
- Plain **F11** shows the desktop in this setup. **Fn + F11** sends volume up.
- Media volume controls work only when macOS can adjust the selected audio output. Some monitor and digital outputs require their own volume controls. Test the Control Center volume slider or switch to MacBook speakers.
- Most plain F1–F12 keys have no universal macOS action. Apps and system shortcut settings determine their behavior; printed media icons refer to the keyboard's secondary layer.
- Firmware-only functions such as lighting and Windows-key lock cannot generally be reassigned through macOS.

No extra software is needed for modifier settings or menu shortcuts. Optional tools such as Karabiner-Elements can inspect and remap recognized key events, but were not installed as part of this setup.

## Cursor movement and text editing

These work in many text fields; editors and terminals may differ.

| Action | Shortcut |
|---|---|
| Previous/next word | Option + ← / → |
| Beginning/end of line | Command + ← / → |
| Beginning/end of document | Command + ↑ / ↓ |
| Paragraph navigation | Option + ↑ / ↓ |
| Select while moving | Add Shift to a movement shortcut |
| Delete previous word | Option + Backspace |
| Delete back to beginning of line | Command + Backspace |
| Delete next character | Forward Delete / Del |

### Without reaching for arrows

| Action | Shortcut |
|---|---|
| Beginning/end of line or paragraph | Control + A / E |
| Previous/next character | Control + B / F |
| Previous/next line | Control + P / N |
| Delete previous/next character | Control + H / D |
| Delete through end of line or paragraph | Control + K |

These Control bindings are conventions, not universal shortcuts. At an empty shell prompt, **Control + D can exit the shell**.

Home/End often scroll to the beginning/end of the document rather than moving the cursor along a line.

For customization, use an editor's own shortcut settings. Many Apple text-system apps also honor `~/Library/KeyBindings/DefaultKeyBinding.dict`, but this is not universal. Cursor movements usually aren't menu commands, so App Shortcuts often cannot assign them.

## Sleep, display sleep, and locking

The Apple logo at the top left opens the **Apple menu**.

| Action | Effect |
|---|---|
| Apple menu → Sleep | Sleeps the Mac and turns off its displays; active work normally pauses |
| Display sleep | Turns off displays without itself requesting whole-system sleep; normal power settings still apply |
| Control + Command + Q | Locks the session without immediately requesting sleep |

To assign a shortcut to **Sleep**, add an **All Applications** App Shortcut with the exact menu title `Sleep`. Verify it appears in the Apple menu.

For display-only sleep without extra software, use **System Settings → Desktop & Dock → Hot Corners → Put Display to Sleep**. Hold a modifier when selecting the action to require that modifier when activating the corner.

### Require authentication on wake

Under **System Settings → Lock Screen**, set **Require password after screen saver begins or display is turned off** to **Immediately** if you want authentication required upon waking the display or Mac.

A delay allows access before it expires. To lock explicitly regardless of that delay, press **Control + Command + Q** before sleeping.
