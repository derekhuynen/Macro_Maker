#Requires AutoHotkey v2.0

#Include record_macro\record_macro.ahk

; Initialize the Macro Recorder with default hotkeys:
; F8 = Start/Stop recording, F9 = Play, F10 = Save
MacroRecorder()

; Brief startup hint (auto-hides)
ToolTip "Macro Maker ready — F8: Rec/Stop, F9: Play, F10: Save", 10, 10
SetTimer () => ToolTip(), -2000

; F12 cancels the program
Hotkey "F12", (*) => ExitApp(), "On"