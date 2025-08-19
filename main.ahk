#Requires AutoHotkey v2.0

#Include record_macro\record_macro.ahk
#Include helper_functions\ui_display.ahk

; Initialize the Macro Recorder with default hotkeys:
; F8 = Start/Stop recording, F9 = Play, F10 = Save
; Initialize UI first so buttons send hotkeys; customize UI hotkeys mapping
ui_init({
    record: "F8",
    play: "F9",
    save: "F10",
    load: "F11",
    loop: "+F9",
    hide: "F6",
    remove: "^F6",
    exit: "F12"
})

; Initialize the Macro Recorder with default hotkeys
MacroRecorder()

ui_set_status("Ready — F8: Rec/Stop, F9: Play, F10: Save, F11: Load")

; F12 cancels the program
Hotkey "F12", (*) => ExitApp(), "On"

; Hotkeys to hide/show UI and to remove it
Hotkey "F6", (*) => ui_toggle_visibility(), "On"
Hotkey "^F6", (*) => ui_destroy(), "On"