# Macro Maker

An AutoHotkey v2 tool to record and play back mouse-click macros with human-like movement and timing.

## Overview

Macro Maker records mouse clicks (with screen positions and delays) and replays them using smooth, natural mouse paths and slight click offset ("click bloom") to avoid robotic precision. A minimal tooltip provides brief status messages.

## Features

- Record mouse clicks (position + delay between clicks)
- Smooth human-like playback (Bezier + easing) with click bloom
- Save recorded macro to INI and load/play saved macros
- Always-available cancel hotkey

## Default Hotkeys

- F8 — Start/Stop recording
- F9 — Play the in-memory macro
- F10 — Save the in-memory macro to `saved_macros/<name>.ini`
- F11 — Load a saved macro by name and play it immediately
- F12 — Cancel/Exit the program

You can change these by editing `main.ahk` and calling:

- `MacroRecorder(startStop, play, save, bloomRadius, load)`
  - Example: `MacroRecorder("F7", "F8", "F9", 12, "F6")`

## How Recording and Playback Work

- Recording captures only mouse clicks (left, right, middle) with their screen coordinates and the delay since the previous action.
- Playback moves from the current cursor position to the next recorded position using `random_mouse_movement.ahk` (Bezier curve with ease-in/out) and then clicks using `click_bloom.ahk` (moves slightly within a radius and clicks).
- Screen coordinates are used (`CoordMode "Mouse", "Screen"`) for consistency across apps/monitors.

### Save Format (INI)

Macros are saved as INI files under `saved_macros/` with this structure:

- Section: `[macro]`
- Key: `count` = number of steps
- Steps: `step1`, `step2`, ... each line like:
  - `delay=123;mouse=LButton;x=100;y=200`

## Usage

1. Run `main.ahk` with AutoHotkey v2.
2. Press F8 to start recording; click where needed; press F8 again to stop.
3. Press F9 to play back from the current cursor position.
4. Press F10 to save to an INI in `saved_macros/`.
5. Press F11 to load a saved macro by name and play it.
6. Press F12 any time to exit.

## File Structure

- `main.ahk` — Entry point; initializes the recorder and global hotkeys
- `record_macro/record_macro.ahk` — Macro recorder (record/play/save/load)
- `helper_functions/`
  - `random_mouse_movement.ahk` — Smooth mouse path with easing/jitter
  - `click_bloom.ahk` — Move to a nearby pixel and click (performs the click)
  - `random_time_delay.ahk` — Returns a random time in ms within a range
- `saved_macros/` — Saved macro INI files
- `scripts/`
  - `click_2_locations.ahk` — Example script that moves and clicks between two points

## Notes

- Playback includes slight randomness to mimic human behavior.
- Large/multi-monitor setups are supported via screen coordinates.
- Use F12 to safely exit at any time.

---

Contributions and suggestions are welcome!
