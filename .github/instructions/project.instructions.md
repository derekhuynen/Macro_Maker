---
applyTo: '**'
---

# Macro Maker — Project Instructions for LLMs

## Project Context

This project is an AutoHotkey v2-based Macro Maker for Windows. It allows users to record, save, and play back sequences of mouse and keyboard actions with human-like randomness. The tool is designed for automation, repetitive tasks, and gaming macros, with a focus on undetectable, natural behavior.

## UI/UX

- The UI is a borderless, always-on-top tooltip in the upper left corner of the screen.
- The UI is click-through (does not block mouse events).
- All user interaction is via hotkeys or the tooltip.

## Core Features

- Record mouse clicks (with positions) and keypresses.
- Save, load, clear, and play macros.
- Play back macros with random time delays and human-like mouse movement.
- Click bloom: Mouse clicks are randomized within a radius to avoid robotic precision.

## Helper Functions

- `random_time_delay`: Adds a small, random delay between actions.
- `random_mouse_movement`: Moves the mouse in a human-like, non-linear path.
- `click_bloom`: Randomizes click location within a set radius.

## Coding Guidelines

- Use AutoHotkey v2 syntax and best practices.
- Organize reusable logic in the `helper_functions/` directory.
- Store user macros in the `saved_macros/` directory.
- Code should be modular, readable, and well-commented.
- Prioritize user safety and avoid destructive actions by default.

## File Structure

- `main.ahk`: Main entry point and UI logic.
- `helper_functions/`: Helper scripts for randomness and mouse movement.
- `saved_macros/`: Saved macro files.

## Notes for LLMs

- All UI and automation must be compatible with Windows and AutoHotkey v2.
- Emphasize human-like randomness in all automated actions.
- Ensure the UI remains non-intrusive and always visible.
- Avoid hard-coding screen coordinates or delays; use parameters and randomness.

---

This file provides context and coding standards for LLMs and contributors working on Macro Maker.
