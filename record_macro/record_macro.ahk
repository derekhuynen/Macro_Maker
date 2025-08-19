#Requires AutoHotkey v2.0

#Include ..\helper_functions\click_bloom.ahk
#Include ..\helper_functions\random_mouse_movement.ahk

; Macro Recorder Module (AutoHotkey v2)
; Provides: MacroRecorder(startStopHotkey?, playHotkey?, saveHotkey?, bloomRadius?)
; - Toggle recording with startStopHotkey
; - Play with playHotkey
; - Save to saved_macros/*.ini with saveHotkey
; Records: mouse clicks (position + button), continuous mouse movement (sampled), and pauses. Keys are not recorded.

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
            ToolTip "Recording stopped (" recorder.macro.Length ")", 10, 10
            SetTimer () => ToolTip(), -800
        } else {
            recorder.macro := []
            recorder.lastTick := A_TickCount
            recorder.recording := true
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
        loop {
            ; Capture starting mouse pos to compute paths
            curX := 0, curY := 0
            MouseGetPos &curX, &curY
            for step in recorder.macro {
                if (recorder.cancel)
                    break
                SleepWithCancel(Max(0, step["delay"])) ; respect recorded delay
                if (recorder.cancel)
                    break
                if (step["type"] = "mouse") {
                    tx := step["x"], ty := step["y"]
                    dur := ComputeMoveDuration(curX, curY, tx, ty)
                    random_mouse_movement(curX, curY, tx, ty, dur, true, recorder.bloomRadius)
                    curX := tx, curY := ty
                } else if (step["type"] = "move") {
                    ; Reproduce recorded path point-by-point for smoothness
                    MouseMove step["x"], step["y"], 0
                    curX := step["x"], curY := step["y"]
                } else if (step["type"] = "pause") {
                    ; Nothing else after sleeping the delay for pause
                }
            }
            if (recorder.cancel || !recorder.loop)
                break
        }
        recorder.playing := false
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
        if (step["type"] = "mouse")
            return "delay=" step["delay"] ";mouse=" step["button"] ";x=" step["x"] ";y=" step["y"]
        if (step["type"] = "move")
            return "delay=" step["delay"] ";move=1;x=" step["x"] ";y=" step["y"]
        ; pause step
        return "delay=" step["delay"] ";pause=1"
    }

    ParseStep(line) {
        ; Format examples:
        ;  - delay=NNN;mouse=Btn;x=NN;y=NN
        ;  - delay=NNN;move=1;x=NN;y=NN
        ;  - delay=NNN;pause=1
        parts := StrSplit(line, ";")
        delay := 0, btn := "", x := "", y := "", isPause := false, isMove := false
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
                else if (k = "pause")
                    isPause := (v != "0")
                else if (k = "move")
                    isMove := (v != "0")
            }
        }
        if (isPause)
            return Map("type", "pause", "delay", delay)
        if (isMove && x != "" && y != "")
            return Map("type", "move", "x", x, "y", y, "delay", delay)
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

    ToggleLoop() {
        recorder.loop := !recorder.loop
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
}
