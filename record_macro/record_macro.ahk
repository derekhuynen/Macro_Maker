#Requires AutoHotkey v2.0

#Include ..\helper_functions\random_mouse_movement.ahk
#Include ..\helper_functions\bloom.ahk

; Macro Recorder Module (AutoHotkey v2)
; Provides: MacroRecorder(startStopHotkey?, playHotkey?, saveHotkey?, bloomRadius?)
; - Toggle recording with startStopHotkey
; - Play with playHotkey
; - Save to saved_macros/*.ini with saveHotkey
; Records: mouse clicks (position + button), continuous mouse movement (sampled), key presses with modifiers, and pauses.

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
        playing: false,
        cancel: false,
        loop: false,
        handlersRegistered: false,
        ; movement sampling
        moveTimerMs: 15,
        moveThresholdPx: 2,
        lastX: 0,
        lastY: 0,
        moveTimerOn: false
    }

    CoordMode "Mouse", "Screen"

    ; Register control hotkeys
    Hotkey startStopHotkey, (*) => ToggleRecording(), "On"
    Hotkey playHotkey, (*) => TogglePlay(), "On"
    Hotkey saveHotkey, (*) => SaveMacro(), "On"
    Hotkey loadHotkey, (*) => LoadAndPlay(), "On"
    ; Shift+Play hotkey toggles loop mode
    try Hotkey "+" . playHotkey, (*) => ToggleLoop(), "On"

    ; Register capture hotkeys (mouse buttons + keyboard press)
    if (!recorder.handlersRegistered) {
        ; Mouse buttons (down only). Use a shared handler to avoid capturing loop variables.
        for mkey in ["LButton", "RButton", "MButton"] {
            try {
                Hotkey "*~" mkey, OnMouseHotkey, "On"
            } catch as e {
            }
        }

        ; Keyboard keys (down only). We record with modifiers state.
        for k in GetKeyCaptureList() {
            try {
                Hotkey "*~" k, OnKeyHotkey, "On"
            } catch as e {
            }
        }
        recorder.handlersRegistered := true
    }

    ; Start a lightweight timer to sample mouse movement while recording
    if (!recorder.moveTimerOn) {
        SetTimer TrackMouseMovement, recorder.moveTimerMs
        recorder.moveTimerOn := true
    }

    ;
    ; Local functions (closures use 'recorder' above)
    ;

    ToggleRecording() {
        if (recorder.recording) {
            ; On stop: capture final idle time as a pause step
            finalDelay := A_TickCount - recorder.lastTick
            if (finalDelay > 0) {
                recorder.macro.Push(Map("type", "pause", "delay", finalDelay))
            }
            recorder.recording := false
            try ui_set_recording(false)
            ToolTip "Recording stopped (" recorder.macro.Length ")", 10, 10
            SetTimer () => ToolTip(), -800
        } else {
            recorder.macro := []
            recorder.lastTick := A_TickCount
            recorder.recording := true
            try ui_set_recording(true)
            _lx := 0, _ly := 0
            MouseGetPos &_lx, &_ly
            recorder.lastX := _lx
            recorder.lastY := _ly
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
        mods := Map(
            "shift", GetKeyState("Shift", "P") ? 1 : 0,
            "ctrl", GetKeyState("Ctrl", "P") ? 1 : 0,
            "alt", GetKeyState("Alt", "P") ? 1 : 0,
            "win", (GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) ? 1 : 0
        )
        event := Map(
            "type", "mouse",
            "button", button,
            "x", x,
            "y", y,
            "delay", delay,
            "mods", mods
        )
        recorder.macro.Push(event)
    }

    OnMouseHotkey(*) {
        ; Derive which button from A_ThisHotkey (e.g., "*~LButton")
        hk := A_ThisHotkey
        btn := InStr(hk, "LButton") ? "LButton" : InStr(hk, "RButton") ? "RButton" : "MButton"
        RecordMouse(btn)
    }

    OnKeyHotkey(*) {
        if (!recorder.recording)
            return
        hk := A_ThisHotkey ; e.g., "*~a"
        ; Extract the base key name we registered
        base := hk
        if (SubStr(base, 1, 2) = "*~")
            base := SubStr(base, 3)

        ; Ignore control hotkeys (start/stop/play/save/load)
        if (base = recorder.startStopKey || base = recorder.playKey || base = recorder.saveKey || base = recorder.loadKey
        )
            return

        delay := A_TickCount - recorder.lastTick
        recorder.lastTick := A_TickCount

        mods := Map(
            "shift", GetKeyState("Shift", "P") ? 1 : 0,
            "ctrl", GetKeyState("Ctrl", "P") ? 1 : 0,
            "alt", GetKeyState("Alt", "P") ? 1 : 0,
            "win", (GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) ? 1 : 0
        )

        recorder.macro.Push(Map(
            "type", "key",
            "key", base,
            "mods", mods,
            "delay", delay
        ))
    }

    TrackMouseMovement() {
        if (!recorder.recording)
            return
        x := 0, y := 0
        MouseGetPos &x, &y
        dx := x - recorder.lastX
        dy := y - recorder.lastY
        if ((dx * dx + dy * dy) < (recorder.moveThresholdPx * recorder.moveThresholdPx))
            return
        ; record a movement step with elapsed time since last event
        delay := A_TickCount - recorder.lastTick
        recorder.lastTick := A_TickCount
        recorder.lastX := x
        recorder.lastY := y
        recorder.macro.Push(Map(
            "type", "move",
            "x", x,
            "y", y,
            "delay", delay
        ))
    }

    TogglePlay() {
        if (recorder.playing) {
            recorder.cancel := true
            try ui_set_playing(false)
            ToolTip "Stopping playback...", 10, 10
            SetTimer () => ToolTip(), -500
            return
        }
        if (recorder.macro.Length = 0) {
            ToolTip "No macro recorded", 10, 10
            SetTimer () => ToolTip(), -800
            return
        }
        PlayMacro()
    }

    PlayMacro() {
        if (recorder.recording)
            return ; avoid self-capture or interference
        recorder.cancel := false
        recorder.playing := true
        try {
            ui_set_step(0, recorder.macro.Length)
            ui_set_time(0)
            ui_set_playing(true)
            ui_set_loop(recorder.loop)
        }
        loop {
            ; Capture starting mouse pos to compute paths
            curX := 0, curY := 0
            MouseGetPos &curX, &curY
            idx := 0
            for step in recorder.macro {
                idx++
                if (recorder.cancel)
                    break
                try ui_set_step(idx, recorder.macro.Length)
                if (step["type"] = "move") {
                    ; Match recorded speed: use the recorded delay as the move duration
                    MouseGetPos &curX, &curY
                    tx := step["x"], ty := step["y"]
                    dur := Max(1, step["delay"]) ; avoid 0-duration which would jump
                    random_mouse_movement(curX, curY, tx, ty, dur, false, recorder.bloomRadius)
                    curX := tx, curY := ty
                } else if (step["type"] = "mouse") {
                    SleepWithCancel(Max(0, step["delay"]))
                    if (recorder.cancel)
                        break
                    ; Bloom the click target and use it for both travel and click
                    ; Re-capture current cursor position in case user moved the mouse during playback
                    MouseGetPos &curX, &curY
                    loc := bloom(step["x"], step["y"], recorder.bloomRadius)
                    bx := loc[1], by := loc[2]
                    dur := ComputeMoveDuration(curX, curY, bx, by)
                    mods := step.Has("mods") ? step["mods"] : Map("shift", 0, "ctrl", 0, "alt", 0, "win", 0)
                    PressMods(mods)
                    random_mouse_movement(curX, curY, bx, by, dur, true, recorder.bloomRadius)
                    ReleaseMods(mods)
                    curX := bx, curY := by
                } else if (step["type"] = "key") {
                    SleepWithCancel(Max(0, step["delay"]))
                    if (recorder.cancel)
                        break
                    Send BuildSendChord(step)
                } else if (step["type"] = "pause") {
                    SleepWithCancel(Max(0, step["delay"]))
                    ; Nothing else after sleeping the delay for pause
                }
            }
            if (recorder.cancel || !recorder.loop)
                break
        }
        recorder.playing := false
        try ui_set_playing(false)
        recorder.cancel := false
        if (recorder.loop)
            ToolTip "Loop stopped or completed.", 10, 10
        SetTimer () => ToolTip(), -600
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
            TogglePlay()
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
        if (step["type"] = "mouse") {
            sm := step.Has("mods") ? step["mods"] : Map("shift", 0, "ctrl", 0, "alt", 0, "win", 0)
            return "delay=" step["delay"] ";mouse=" step["button"] ";x=" step["x"] ";y=" step["y"] ";shift=" sm["shift"
            ] ";ctrl=" sm["ctrl"] ";alt=" sm["alt"] ";win=" sm["win"]
        }
        if (step["type"] = "key") {
            mods := step["mods"]
            return "delay=" step["delay"] ";key=" step["key"] ";shift=" mods["shift"] ";ctrl=" mods["ctrl"] ";alt=" mods[
                "alt"] ";win=" mods["win"]
        }
        if (step["type"] = "move")
            return "delay=" step["delay"] ";move=1;x=" step["x"] ";y=" step["y"]
        ; pause step
        return "delay=" step["delay"] ";pause=1"
    }

    ParseStep(line) {
        ; Format examples:
        ;  - delay=NNN;mouse=Btn;x=NN;y=NN
        ;  - delay=NNN;key=a;shift=1;ctrl=0;alt=0;win=0
        ;  - delay=NNN;move=1;x=NN;y=NN
        ;  - delay=NNN;pause=1
        parts := StrSplit(line, ";")
        delay := 0, btn := "", x := "", y := "", isPause := false, isMove := false, key := "", shift := 0, ctrl := 0,
            alt := 0, win := 0
        for p in parts {
            kv := StrSplit(p, "=", , 2)
            if (kv.Length >= 2) {
                k := Trim(kv[1])
                v := Trim(kv[2])
                if (k = "delay")
                    delay := 0 + v
                else if (k = "mouse")
                    btn := v
                else if (k = "key")
                    key := v
                else if (k = "x")
                    x := 0 + v
                else if (k = "y")
                    y := 0 + v
                else if (k = "pause")
                    isPause := (v != "0")
                else if (k = "move")
                    isMove := (v != "0")
                else if (k = "shift")
                    shift := 0 + v
                else if (k = "ctrl")
                    ctrl := 0 + v
                else if (k = "alt")
                    alt := 0 + v
                else if (k = "win")
                    win := 0 + v
            }
        }
        if (isPause)
            return Map("type", "pause", "delay", delay)
        if (isMove && x != "" && y != "")
            return Map("type", "move", "x", x, "y", y, "delay", delay)
        if (key != "") {
            return Map(
                "type", "key",
                "key", key,
                "mods", Map("shift", shift, "ctrl", ctrl, "alt", alt, "win", win),
                "delay", delay
            )
        }
        if (btn = "" || x = "" || y = "")
            return false
        return Map("type", "mouse", "button", btn, "x", x, "y", y, "delay", delay,
            "mods", Map("shift", shift, "ctrl", ctrl, "alt", alt, "win", win))
    }

    Clamp(val, lo, hi) {
        if (val < lo)
            return lo
        if (val > hi)
            return hi
        return val
    }

    ToggleLoop() {
        recorder.loop := !recorder.loop
        try ui_set_loop(recorder.loop)
        ToolTip "Loop: " (recorder.loop ? "ON" : "OFF") " (Shift+" recorder.playKey ")", 10, 10
        SetTimer () => ToolTip(), -800
    }

    SleepWithCancel(ms) {
        ; Sleep in small chunks to allow responsive stop via F9
        remaining := ms
        while (remaining > 0 && !recorder.cancel) {
            chunk := remaining > 25 ? 25 : remaining
            Sleep chunk
            remaining -= chunk
        }
    }

    ; --- keyboard helpers ---

    PressMods(mods) {
        if (!IsObject(mods))
            return
        if (mods["ctrl"]) {
            Send "{Ctrl down}"
        }
        if (mods["alt"]) {
            Send "{Alt down}"
        }
        if (mods["shift"]) {
            Send "{Shift down}"
        }
        if (mods["win"]) {
            Send "{LWin down}"
        }
    }

    ReleaseMods(mods) {
        if (!IsObject(mods))
            return
        if (mods["win"]) {
            Send "{LWin up}"
        }
        if (mods["shift"]) {
            Send "{Shift up}"
        }
        if (mods["alt"]) {
            Send "{Alt up}"
        }
        if (mods["ctrl"]) {
            Send "{Ctrl up}"
        }
    }

    GetKeyCaptureList() {
        keys := []
        ; Letters
        for c in StrSplit("abcdefghijklmnopqrstuvwxyz", "")
            keys.Push(c)
        ; Digits
        for c in StrSplit("0123456789", "")
            keys.Push(c)
        ; Function keys
        i := 1
        while (i <= 24) {
            keys.Push("F" i)
            i++
        }
        ; Navigation and common
        for k in ["Enter", "Space", "Tab", "Esc", "Escape", "Backspace", "Delete", "Insert", "Home", "End", "PgUp",
            "PgDn", "Up", "Down", "Left", "Right", "AppsKey", "PrintScreen", "Pause", "CtrlBreak", "CapsLock",
            "NumLock", "ScrollLock",
            "Numpad0", "Numpad1", "Numpad2", "Numpad3", "Numpad4", "Numpad5", "Numpad6", "Numpad7", "Numpad8",
            "Numpad9",
            "NumpadDiv", "NumpadMult", "NumpadAdd", "NumpadSub", "NumpadEnter", "NumpadDot"]
            keys.Push(k)
        return keys
    }

    BuildSendChord(step) {
        mods := step["mods"]
        prefix := (mods["ctrl"] ? "^" : "") (mods["alt"] ? "!" : "") (mods["shift"] ? "+" : "") (mods["win"] ? "#" : ""
        )
        k := step["key"]
        return prefix . FormatKeyForSend(k)
    }

    FormatKeyForSend(k) {
        if (IsKeyRequiringBraces(k))
            return "{" k "}"
        return k
    }

    IsKeyRequiringBraces(k) {
        static special := Map(
            "Enter", 1, "Space", 1, "Tab", 1, "Esc", 1, "Escape", 1, "Backspace", 1, "Delete", 1, "Insert", 1, "Home",
            1, "End", 1,
            "PgUp", 1, "PgDn", 1, "Up", 1, "Down", 1, "Left", 1, "Right", 1, "AppsKey", 1, "PrintScreen", 1, "Pause", 1,
            "CtrlBreak", 1,
            "CapsLock", 1, "NumLock", 1, "ScrollLock", 1,
            "Numpad0", 1, "Numpad1", 1, "Numpad2", 1, "Numpad3", 1, "Numpad4", 1, "Numpad5", 1, "Numpad6", 1, "Numpad7",
            1, "Numpad8", 1, "Numpad9", 1,
            "NumpadDiv", 1, "NumpadMult", 1, "NumpadAdd", 1, "NumpadSub", 1, "NumpadEnter", 1, "NumpadDot", 1
        )
        if (special.Has(k))
            return true
        ; Function keys
        if RegExMatch(k, "^F([1-9]|1[0-9]|2[0-4])$")
            return true
        return false
    }
}
