
; UI Display for Macro Maker (upper right corner)
; Shows: Current Step, Total Steps, Mouse Location, Timer

global ui_display_values := {CurrentStep: 0, TotalSteps: 0, MouseX: 0, MouseY: 0, Timer: "00:00"}
global ui_display_tooltip_id := 0

ui_display_update(CurrentStep := "", TotalSteps := "", MouseX := "", MouseY := "", Timer := "") {
	if (CurrentStep != "") ui_display_values.CurrentStep := CurrentStep
	if (TotalSteps != "") ui_display_values.TotalSteps := TotalSteps
	if (MouseX != "") ui_display_values.MouseX := MouseX
	if (MouseY != "") ui_display_values.MouseY := MouseY
	if (Timer != "") ui_display_values.Timer := Timer
	ui_display_render()
}

ui_display_render() {
	text := "Current Step: " ui_display_values.CurrentStep " / " ui_display_values.TotalSteps "\n"
		. "Mouse: (" ui_display_values.MouseX ", " ui_display_values.MouseY ")\n"
		. "Timer: " ui_display_values.Timer


	; Get screen dimensions (AHK v2 syntax)
	screenWidth := SysGet(78)
	screenHeight := SysGet(79)
	tooltipWidth := 200
	tooltipHeight := 60
	x := screenWidth - tooltipWidth - 10
	y := 10


	; Show tooltip (borderless, always-on-top, click-through)
	if (ui_display_tooltip_id) {
		ToolTip(, , , ui_display_tooltip_id) ; Clear previous
	}
	ToolTip(text, x, y, 99)
	ui_display_tooltip_id := 99

	; Make tooltip click-through (requires WinSet)
	; Use the built-in function from the global namespace to avoid local variable warning
	%WinSet% := Func('WinSet')
	%WinSet%('ExStyle', '+0x20', 'ahk_class tooltips_class32')
}

ui_display_hide() {
	ToolTip
	ui_display_tooltip_id := 0
}
