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
        playing: false,
        cancel: false,
        loop: false,
        ; mouse move recording settings
        recordMoves: true,
        moveSampleMs: 25,
        moveMinDist: 10,
        lastMoveX: 0,
        lastMoveY: 0,
        ; key recording settings
        recordKeys: true,
        handlersRegistered: false
    }

    CoordMode "Mouse", "Screen"

    ; Register control hotkeys
    Hotkey startStopHotkey, (*) => ToggleRecording(), "On"
    Hotkey playHotkey, (*) => TogglePlay(), "On"
    Hotkey saveHotkey, (*) => SaveMacro(), "On"
    Hotkey loadHotkey, (*) => LoadAndPlay(), "On"
    ; Shift+Play hotkey toggles loop mode
    try Hotkey "+" . playHotkey, (*) => ToggleLoop(), "On"

    ; Register capture hotkeys (mouse buttons + keys)
    if (!recorder.handlersRegistered) {
        ; Mouse buttons (down only). Use a shared handler to avoid capturing loop variables.
        for mkey in ["LButton", "RButton", "MButton"] {
            try {
                Hotkey "*~" mkey, OnMouseHotkey, "On"
            } catch as e {
            }
        }
        ; Keys (letters, digits, function keys, navigation, numpad)
        if (recorder.recordKeys) {
            for key in GetRecordableKeys() {
                try {
                    Hotkey "*~" key, OnKeyHotkey, "On"
                } catch as e {
                }
            }
        }
        recorder.handlersRegistered := true
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
            ; stop move sampler
            SetTimer OnMoveSample, 0
            recorder.recording := false
            ToolTip "Recording stopped (" recorder.macro.Length ")", 10, 10
            SetTimer () => ToolTip(), -800
        } else {
            recorder.macro := []
            recorder.lastTick := A_TickCount
            recorder.recording := true
            ; initialize move sampler
            if (recorder.recordMoves) {
                x0 := 0, y0 := 0
                MouseGetPos &x0, &y0
                recorder.lastMoveX := x0
                recorder.lastMoveY := y0
                SetTimer OnMoveSample, recorder.moveSampleMs
            }
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
                delay := Max(0, step["delay"]) ; target time budget to reach this step
                if (step["type"] = "mouse") {
                    tx := step["x"], ty := step["y"]
                    if (delay > 0) {
                        ; Move over the delay and click exactly on time
                        random_mouse_movement(curX, curY, tx, ty, delay, true, recorder.bloomRadius)
                    } else {
                        ; Immediate click at target
                        MouseMove tx, ty, 0
                        click_bloom(tx, ty, recorder.bloomRadius)
                    }
                    curX := tx, curY := ty
                } else if (step["type"] = "move") {
                    if (delay > 0) {
                        random_mouse_movement(curX, curY, step["x"], step["y"], delay, false, recorder.bloomRadius)
                    } else {
                        MouseMove step["x"], step["y"], 0
                    }
                    curX := step["x"], curY := step["y"]
                } else if (step["type"] = "key") {
                    SleepWithCancel(delay)
                    if (recorder.cancel)
                        break
                    SendKeyWithMods(step["key"], step["mods"])
                } else if (step["type"] = "pause") {
                    SleepWithCancel(delay)
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
        if (step["type"] = "key") {
            mods := step["mods"].Length ? JoinArray(step["mods"], "+") : ""
            return "delay=" step["delay"] ";key=" step["key"] ";mods=" mods
        }
        ; pause step
        return "delay=" step["delay"] ";pause=1"
    }

    ParseStep(line) {
        ; Format examples:
        ;  - delay=NNN;mouse=Btn;x=NN;y=NN
        ;  - delay=NNN;move=1;x=NN;y=NN
        ;  - delay=NNN;key=K;mods=Ctrl+Shift
        ;  - delay=NNN;pause=1
        parts := StrSplit(line, ";")
        delay := 0, btn := "", x := "", y := "", isPause := false, isMove := false, key := "", modsStr := ""
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
                else if (k = "move")
                    isMove := (v != "0")
                else if (k = "key")
                    key := v
                else if (k = "mods")
                    modsStr := v
                else if (k = "pause")
                    isPause := (v != "0")
            }
        }
        if (isPause)
            return Map("type", "pause", "delay", delay)
        if (isMove) {
            if (x = "" || y = "")
                return false
            return Map("type", "move", "x", x, "y", y, "delay", delay)
        }
        if (key != "") {
            mods := modsStr ? StrSplit(modsStr, "+") : []
            return Map("type", "key", "key", key, "mods", mods, "delay", delay)
        }
        if (btn = "" || x = "" || y = "")
            return false
        return Map("type", "mouse", "button", btn, "x", x, "y", y, "delay", delay)
    }

    OnMoveSample() {
        if (!recorder.recording || !recorder.recordMoves)
            return
        cx := 0, cy := 0
        MouseGetPos &cx, &cy
        dx := cx - recorder.lastMoveX
        dy := cy - recorder.lastMoveY
        dist2 := dx * dx + dy * dy
        if (dist2 < recorder.moveMinDist * recorder.moveMinDist)
            return
        delay := A_TickCount - recorder.lastTick
        recorder.lastTick := A_TickCount
        recorder.macro.Push(Map("type", "move", "x", cx, "y", cy, "delay", delay))
        recorder.lastMoveX := cx
        recorder.lastMoveY := cy
    }

    OnKeyHotkey(*) {
        if (!recorder.recording || !recorder.recordKeys)
            return
        ; Determine key name from A_ThisHotkey (strip *~ prefixes)
        hk := A_ThisHotkey
        ; remove leading modifiers like * and ~
        while (SubStr(hk, 1, 1) = "*" || SubStr(hk, 1, 1) = "~")
            hk := SubStr(hk, 2)
        keyName := hk
        ; Skip control hotkeys to avoid recording them
        if (keyName = recorder.startStopKey || keyName = recorder.playKey || keyName = recorder.saveKey || keyName =
            recorder.loadKey)
            return
        ; Compute delay and capture modifiers
        delay := A_TickCount - recorder.lastTick
        recorder.lastTick := A_TickCount
        mods := []
        for m in ["Ctrl", "Shift", "Alt", "LWin", "RWin"] {
            if GetKeyState(m, "P")
                mods.Push(m)
        }
        recorder.macro.Push(Map("type", "key", "key", keyName, "mods", mods, "delay", delay))
    }

    GetRecordableKeys() {
        letters := ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
            "u", "v", "w", "x", "y", "z"]
        digits := ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        funcs := []
        loop 24
            funcs.Push("F" . A_Index)
        specials := ["Space", "Enter", "Tab", "Escape", "Backspace", "Delete", "Insert", "Home", "End", "PgUp", "PgDn",
            "Up", "Down", "Left", "Right"]
        numpad := ["Numpad0", "Numpad1", "Numpad2", "Numpad3", "Numpad4", "Numpad5", "Numpad6", "Numpad7", "Numpad8",
            "Numpad9", "NumpadAdd", "NumpadSub", "NumpadMult", "NumpadDiv", "NumpadEnter", "NumpadDot"]
        all := []
        for v in letters
            all.Push(v)
        for v in digits
            all.Push(v)
        for v in funcs
            all.Push(v)
        for v in specials
            all.Push(v)
        for v in numpad
            all.Push(v)
        return all
    }

    SendKeyWithMods(key, mods) {
        ; Hold modifiers
        for m in mods
            Send "{" m " down}"
        ; Send key (brace special names)
        if (StrLen(key) = 1 && RegExMatch(key, "^[A-Za-z0-9]$"))
            Send key
        else
            Send "{" key "}"
        ; Release modifiers (reverse order)
        i := mods.Length
        while (i >= 1) {
            m := mods[i]
            Send "{" m " up}"
            i--
        }
    }

    JoinArray(arr, sep) {
        out := ""
        for idx, v in arr
            out .= (idx = 1 ? "" : sep) v
        return out
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
