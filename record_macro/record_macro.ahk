#Requires AutoHotkey v2.0

#Include ..\helper_functions\click_bloom.ahk
#Include ..\helper_functions\random_mouse_movement.ahk

; Macro Recorder Module (AutoHotkey v2)
; Provides: MacroRecorder(startStopHotkey?, playHotkey?, saveHotkey?, bloomRadius?)
; - Toggle recording with startStopHotkey
; - Play with playHotkey
; - Save to saved_macros/*.ini with saveHotkey
; Records: mouse clicks (position + button) and delay between clicks. Keys are not recorded.

; Usage:
;   MacroRecorder() ; defaults: F8 (start/stop), F9 (play), F10 (save), F11 (load)
;   or customize: MacroRecorder("F7", "F8", "F9", 10)

MacroRecorder(startStopHotkey := "F8", playHotkey := "F9", saveHotkey := "F10", bloomRadius := 10, loadHotkey := "F11") {
    static recorder := {
        recording: false,
        macro: [],
        lastTick: 0,
        bloomRadius: bloomRadius,
        startStopKey: startStopHotkey,
        playKey: playHotkey,
        saveKey: saveHotkey,
        loadKey: loadHotkey,
        handlersRegistered: false
    }

    CoordMode "Mouse", "Screen"

    ; Register control hotkeys
    Hotkey startStopHotkey, (*) => ToggleRecording(), "On"
    Hotkey playHotkey, (*) => PlayMacro(), "On"
    Hotkey saveHotkey, (*) => SaveMacro(), "On"
    Hotkey loadHotkey, (*) => LoadAndPlay(), "On"

    ; Register capture hotkeys (mouse buttons only)
    if (!recorder.handlersRegistered) {
        ; Mouse buttons (down only). Use a shared handler to avoid capturing loop variables.
        for mkey in ["LButton", "RButton", "MButton"] {
            try {
                Hotkey "*~" mkey, OnMouseHotkey, "On"
            } catch as e {
            }
        }
        recorder.handlersRegistered := true
    }

    ;
    ; Local functions (closures use 'recorder' above)
    ;

    ToggleRecording() {
        if (recorder.recording) {
            recorder.recording := false
            ToolTip "Recording stopped (" recorder.macro.Length ")", 10, 10
            SetTimer () => ToolTip(), -800
        } else {
            recorder.macro := []
            recorder.lastTick := A_TickCount
            recorder.recording := true
            ToolTip "Recording... (" recorder.startStopKey " to stop)", 10, 10
        }
    }

    RecordMouse(button) {
        if (!recorder.recording)
            return
        delay := A_TickCount - recorder.lastTick
        recorder.lastTick := A_TickCount
        x := 0, y := 0
        MouseGetPos &x, &y
        event := Map(
            "type", "mouse",
            "button", button,
            "x", x,
            "y", y,
            "delay", delay
        )
        recorder.macro.Push(event)
    }

    OnMouseHotkey(*) {
        ; Derive which button from A_ThisHotkey (e.g., "*~LButton")
        hk := A_ThisHotkey
        btn := InStr(hk, "LButton") ? "LButton" : InStr(hk, "RButton") ? "RButton" : "MButton"
        RecordMouse(btn)
    }

    PlayMacro() {
        if (recorder.recording)
            return ; avoid self-capture or interference
        if (recorder.macro.Length = 0) {
            ToolTip "No macro recorded", 10, 10
            SetTimer () => ToolTip(), -800
            return
        }
        ; Play back steps with human-like mouse and natural delays
        ; Capture starting mouse pos to compute paths
        curX := 0, curY := 0
        MouseGetPos &curX, &curY
        for step in recorder.macro {
            Sleep Max(0, step["delay"]) ; respect recorded delay as-is
            if (step["type"] = "mouse") {
                tx := step["x"], ty := step["y"]
                dur := ComputeMoveDuration(curX, curY, tx, ty)
                random_mouse_movement(curX, curY, tx, ty, dur, true, recorder.bloomRadius)
                curX := tx, curY := ty
            }
        }
    }

    SaveMacro() {
        if (recorder.recording)
            return ; don't save mid-recording
        result := InputBox("Enter macro name (no extension):", "Save Macro")
        if (result.Result != "OK")
            return
        fileName := result.Value
        if (!fileName)
            fileName := FormatTime(, "yyyyMMdd-HHmmss")
        dir := A_ScriptDir "\\saved_macros"
        if !DirExist(dir)
            DirCreate dir
        path := dir "\\" fileName ".ini"
        ; Serialize steps as step1..N in [macro] section
        IniWrite recorder.macro.Length, path, "macro", "count"
        idx := 0
        for step in recorder.macro {
            idx++
            IniWrite SerializeStep(step), path, "macro", "step" idx
        }
        ToolTip "Saved: " path, 10, 10
        SetTimer () => ToolTip(), -1200
    }

    LoadAndPlay() {
        if (recorder.recording)
            return
        if (LoadMacro())
            PlayMacro()
    }

    LoadMacro() {
        ; Prompt for macro name and load from saved_macros
        result := InputBox("Enter macro name to load (no extension):", "Load Macro")
        if (result.Result != "OK")
            return false
        name := result.Value
        if (!name)
            return false
        dir := A_ScriptDir "\\saved_macros"
        path := dir "\\" name ".ini"
        if !FileExist(path) {
            ToolTip "Not found: " path, 10, 10
            SetTimer () => ToolTip(), -1200
            return false
        }
        count := IniRead(path, "macro", "count", 0)
        if (count <= 0) {
            ToolTip "Empty macro in: " path, 10, 10
            SetTimer () => ToolTip(), -1200
            return false
        }
        steps := []
        i := 1
        while (i <= count) {
            line := IniRead(path, "macro", "step" i, "")
            if (line != "") {
                st := ParseStep(line)
                if (st)
                    steps.Push(st)
            }
            i++
        }
        recorder.macro := steps
        ToolTip "Loaded (" steps.Length ") from: " path, 10, 10
        SetTimer () => ToolTip(), -1000
        return steps.Length > 0
    }

    ; --- helpers ---

    ComputeMoveDuration(x1, y1, x2, y2) {
        dx := x2 - x1, dy := y2 - y1
        dist := Sqrt(dx * dx + dy * dy)
        ; Base 220ms + 0.6ms per px, clamped
        return Clamp(Round(220 + dist * 0.6), 140, 1200)
    }

    SerializeStep(step) {
        ; Only mouse steps are recorded/saved
        return "delay=" step["delay"] ";mouse=" step["button"] ";x=" step["x"] ";y=" step["y"]
    }

    ParseStep(line) {
        ; Expect format: delay=NNN;mouse=Btn;x=NN;y=NN
        parts := StrSplit(line, ";")
        delay := 0, btn := "", x := "", y := ""
        for p in parts {
            kv := StrSplit(p, "=", , 2)
            if (kv.Length >= 2) {
                k := Trim(kv[1])
                v := Trim(kv[2])
                if (k = "delay")
                    delay := 0 + v
                else if (k = "mouse")
                    btn := v
                else if (k = "x")
                    x := 0 + v
                else if (k = "y")
                    y := 0 + v
            }
        }
        if (btn = "" || x = "" || y = "")
            return false
        return Map("type", "mouse", "button", btn, "x", x, "y", y, "delay", delay)
    }

    Clamp(val, lo, hi) {
        if (val < lo)
            return lo
        if (val > hi)
            return hi
        return val
    }
}
