#Requires AutoHotkey v2.0

; Movable UI with minimal controls, status lines, and keybinds
; Public API:
;   ui_init(opts?) -> Gui
;   ui_show(), ui_hide()
;   ui_set_mouse(x, y)
;   ui_set_recording(bool), ui_set_playing(bool), ui_set_loop(bool)
;   ui_set_step(current, total)
;   ui_set_time(ms)

UI := {
    hwnd: 0,
    win: 0,
    controls: {},
    hotkeys: { record: "F8", play: "F9", save: "F10", load: "F11", loop: "+F9", hide: "F6", remove: "^F6", exit: "F12" },
    timers: { tick: 0 },
    state: {
        mouseX: 0,
        mouseY: 0,
        recording: false,
        playing: false,
        loop: false,
        stepCur: 0,
        stepTotal: 0,
        playStartTick: 0,
        playElapsedMs: 0,
        hidden: false,
        idleSwipe: false
    }
}

ui_init(opts := 0) {
    if (Type(opts) = "Object") {
        if (opts.HasOwnProp("record"))
            UI.hotkeys.record := opts.record
        if (opts.HasOwnProp("play"))
            UI.hotkeys.play := opts.play
        if (opts.HasOwnProp("save"))
            UI.hotkeys.save := opts.save
        if (opts.HasOwnProp("load"))
            UI.hotkeys.load := opts.load
        if (opts.HasOwnProp("loop"))
            UI.hotkeys.loop := opts.loop
        if (opts.HasOwnProp("hide"))
            UI.hotkeys.hide := opts.hide
        if (opts.HasOwnProp("remove"))
            UI.hotkeys.remove := opts.remove
        if (opts.HasOwnProp("exit"))
            UI.hotkeys.exit := opts.exit
    }

    g := Gui("+AlwaysOnTop -Caption +ToolWindow", "Macro Maker")
    g.MarginX := 8, g.MarginY := 8
    g.BackColor := "000000"

    ; Top bar (drag area)
    title := g.AddText("cWhite Background000000 w360 h22 +0x100", "Macro Maker") ; SS_NOTIFY
    title.SetFont("s10 Bold")
    title.OnEvent("Click", (*) => PostMessage(0xA1, 2, , g.Hwnd))

    ; Buttons row (only Record and Play)
    gb := g.AddGroupBox("xm Background000000 w360 h44", "")
    ; Place buttons inside the group box using relative previous (xp/yp)
    btnRec := g.AddButton("xp+10 yp+14 w90 h24", "Record")
    btnRec.OnEvent("Click", ui_toggle_record)
    btnPlay := g.AddButton("x+10 yp w90 h24", "Play")
    btnPlay.OnEvent("Click", ui_toggle_play)

    g.AddText("xm Background000000 w360 h1") ; divider

    ; Two columns under the buttons: Info (left), Keybinds (right)
    gbInfo := g.AddGroupBox("xm Background000000 w175 h180", "")
    gbInfo.GetPos(&ix, &iy, &iw, &ih)
    lblTime := g.AddText(Format("x{} y{} cWhite Background000000 w{}", ix + 8, iy + 10, iw - 16), "time: 0:00")
    lblStep := g.AddText(Format("x{} y{} cWhite Background000000 w{}", ix + 8, iy + 30, iw - 16), "step: 0/0")
    lblMouse := g.AddText(Format("x{} y{} cWhite Background000000 w{}", ix + 8, iy + 50, iw - 16), "mouse: 0, 0")
    lblRec := g.AddText(Format("x{} y{} cWhite Background000000 w{}", ix + 8, iy + 70, iw - 16), "recording: false")
    lblPlay := g.AddText(Format("x{} y{} cWhite Background000000 w{}", ix + 8, iy + 90, iw - 16), "playing: false")
    lblLoop := g.AddText(Format("x{} y{} cWhite Background000000 w{}", ix + 8, iy + 110, iw - 16), "loop: false")
    chkIdleSwipe := g.AddCheckbox(Format("x{} y{} cWhite Background000000 w{}", ix + 8, iy + 135, iw - 16),
    "Idle Swipe")
    chkIdleSwipe.OnEvent("Click", ui_toggle_idle_swipe)

    ; Create keybinds box aligned to the info box (same y), 10px to the right
    gbKeys := g.AddGroupBox(Format("x{} y{} w175 h180 Background000000", ix + iw + 10, iy), "")
    gbKeys.GetPos(&kx, &ky, &kw, &kh)
    lblKeysHeader := g.AddText(Format("x{} y{} c808080 Background000000 w{}", kx + 8, ky + 10, kw - 16), "Keybinds:")
    lblKeys := g.AddText(Format("x{} y{} cWhite Background000000 w{} r8", kx + 8, ky + 28, kw - 16), "")
    try lblKeys.SetFont("s9, Consolas")

    UI.win := g
    UI.hwnd := g.Hwnd
    UI.controls.title := title
    UI.controls.btnRec := btnRec
    UI.controls.btnPlay := btnPlay
    UI.controls.lblTime := lblTime
    UI.controls.lblStep := lblStep
    UI.controls.lblMouse := lblMouse
    UI.controls.lblRec := lblRec
    UI.controls.lblPlay := lblPlay
    UI.controls.lblLoop := lblLoop
    UI.controls.chkIdleSwipe := chkIdleSwipe
    UI.controls.lblKeysHeader := lblKeysHeader
    UI.controls.lblKeys := lblKeys

    g.Show("x10 y10")

    if (!UI.timers.tick) {
        SetTimer ui_tick, 200
        UI.timers.tick := 1
    }

    ui_update_keys_label()
    return g
}

ui_show() {
    if UI.win
        UI.win.Show()
    UI.state.hidden := false
}

ui_hide() {
    if UI.win
        UI.win.Hide()
    UI.state.hidden := true
}

; Toggle visibility of the UI window
ui_toggle_visibility() {
    if (!UI.win)
        return
    if (UI.state.hidden)
        ui_show()
    else
        ui_hide()
}

; Destroy the UI and stop timers; safe to call multiple times
ui_destroy() {
    if (UI.timers.tick) {
        try SetTimer ui_tick, 0
        UI.timers.tick := 0
    }
    if (UI.win) {
        try UI.win.Destroy()
    }
    UI.win := 0
    UI.hwnd := 0
    UI.controls := {}
    UI.state.hidden := true
}

ui_set_mouse(x, y) {
    UI.state.mouseX := x, UI.state.mouseY := y
    if (UI.controls.lblMouse)
        UI.controls.lblMouse.Text := "mouse: " x ", " y
}

; Back-compat (no-op)
ui_set_status(text := "") {
}

ui_send_hotkey(hk) {
    if RegExMatch(hk, "^[#\^!+]?F([1-9]|1[0-9]|2[0-4])$") {
        pref := ""
        if (SubStr(hk, 1, 1) ~= "[#\^!+]") {
            pref := SubStr(hk, 1, 1), hk := SubStr(hk, 2)
        }
        Send pref "{" hk "}"
    } else {
        if RegExMatch(hk,
            "^(Enter|Space|Tab|Esc|Escape|Backspace|Delete|Insert|Home|End|PgUp|PgDn|Up|Down|Left|Right|AppsKey|PrintScreen|Pause|CtrlBreak|CapsLock|NumLock|ScrollLock)$"
        )
            Send "{" hk "}"
        else
            Send hk
    }
}

; --- UI state setters ---

ui_set_recording(val) {
    UI.state.recording := !!val
    ui_refresh_controls()
}

ui_set_playing(val) {
    was := UI.state.playing
    UI.state.playing := !!val
    if (UI.state.playing && !was) {
        if (UI.state.playStartTick = 0)
            UI.state.playStartTick := A_TickCount
    } else if (!UI.state.playing && was) {
        if (UI.state.playStartTick) {
            UI.state.playElapsedMs += (A_TickCount - UI.state.playStartTick)
            UI.state.playStartTick := 0
        }
    }
    ui_refresh_controls()
}

ui_set_loop(val) {
    UI.state.loop := !!val
    ui_refresh_controls()
}

ui_set_step(cur, total) {
    UI.state.stepCur := cur
    UI.state.stepTotal := total
    ui_refresh_controls()
}

ui_set_time(ms) {
    UI.state.playElapsedMs := Max(0, ms)
    UI.state.playStartTick := 0
    ui_refresh_controls()
}

ui_set_idle_swipe(val) {
    UI.state.idleSwipe := !!val
    if (UI.controls.chkIdleSwipe)
        UI.controls.chkIdleSwipe.Value := UI.state.idleSwipe
}

ui_get_idle_swipe() {
    return UI.state.idleSwipe
}

; --- Internals ---

ui_tick() {
    MouseGetPos &mx, &my
    ui_set_mouse(mx, my)
    if (UI.state.playing && UI.state.playStartTick)
        ui_update_time_label()
}

ui_update_time_label() {
    totalMs := UI.state.playElapsedMs
    if (UI.state.playStartTick)
        totalMs += (A_TickCount - UI.state.playStartTick)
    sec := Floor(totalMs / 1000)
    mm := Floor(sec / 60)
    ss := Format("{:02}", Mod(sec, 60))
    if (UI.controls.lblTime)
        UI.controls.lblTime.Text := "time: " mm ":" ss
}

ui_refresh_controls() {
    ui_update_time_label()
    if (UI.controls.lblStep)
        UI.controls.lblStep.Text := "step: " UI.state.stepCur "/" UI.state.stepTotal
    if (UI.controls.lblRec)
        UI.controls.lblRec.Text := "recording: " (UI.state.recording ? "true" : "false")
    if (UI.controls.lblPlay)
        UI.controls.lblPlay.Text := "playing: " (UI.state.playing ? "true" : "false")
    if (UI.controls.lblLoop)
        UI.controls.lblLoop.Text := "loop: " (UI.state.loop ? "true" : "false")
    if (UI.controls.lblKeys)
        ui_update_keys_label()

    if (UI.controls.btnRec) {
        if (UI.state.recording) {
            UI.controls.btnRec.Text := "● Record"
            UI.controls.btnRec.SetFont("cRed")
        } else {
            UI.controls.btnRec.Text := "Record"
            UI.controls.btnRec.SetFont("cWhite")
        }
    }
    if (UI.controls.btnPlay) {
        if (UI.state.playing) {
            UI.controls.btnPlay.Text := "Pause"
            UI.controls.btnPlay.SetFont("cLime")
        } else {
            UI.controls.btnPlay.Text := "Play"
            UI.controls.btnPlay.SetFont("cWhite")
        }
    }
}

; --- Button handlers ---

ui_toggle_record(*) {
    ui_set_recording(!UI.state.recording)
    ui_send_hotkey(UI.hotkeys.record)
}

ui_toggle_play(*) {
    ui_set_playing(!UI.state.playing)
    ui_send_hotkey(UI.hotkeys.play)
}

ui_toggle_idle_swipe(*) {
    UI.state.idleSwipe := !UI.state.idleSwipe
    if (UI.controls.chkIdleSwipe)
        UI.controls.chkIdleSwipe.Value := UI.state.idleSwipe
}

; --- Keybind label helpers ---

ui_update_keys_label() {
    if (!UI.controls.lblKeys)
        return
    txt := ""
    txt .= "Record/Stop: " human_hotkey(UI.hotkeys.record) "`n"
    txt .= "Play/Pause:  " human_hotkey(UI.hotkeys.play) "`n"
    txt .= "Save:        " human_hotkey(UI.hotkeys.save) "`n"
    txt .= "Load:        " human_hotkey(UI.hotkeys.load) "`n"
    txt .= "Loop:        " human_hotkey(UI.hotkeys.loop) "`n"
    txt .= "Hide UI:     " human_hotkey(UI.hotkeys.hide) "`n"
    txt .= "Remove UI:   " human_hotkey(UI.hotkeys.remove) "`n"
    txt .= "Exit:        " human_hotkey(UI.hotkeys.exit)
    UI.controls.lblKeys.Text := txt
}

human_hotkey(hk) {
    if (hk = "")
        return ""
    mods := ""
    i := 1
    while (i <= StrLen(hk)) {
        ch := SubStr(hk, i, 1)
        if (ch = "#")
            mods .= "Win+"
        else if (ch = "^")
            mods .= "Ctrl+"
        else if (ch = "!")
            mods .= "Alt+"
        else if (ch = "+")
            mods .= "Shift+"
        else
            break
        i++
    }
    key := SubStr(hk, i)
    return mods . key
}
