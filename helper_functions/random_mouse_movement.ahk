; Moves the mouse from (x1, y1) to (x2, y2) in a human-like, non-linear path over the given duration (ms)
; If doClick is true, performs a click at the end
; Requires click_bloom.ahk in the same directory or #Include'd
random_mouse_movement(x1, y1, x2, y2, duration, doClick := false, bloomRadius := 5) {
    ; Steps scale with distance for smoothness
    dx := x2 - x1
    dy := y2 - y1
    dist := Sqrt(dx * dx + dy * dy)
    steps := Round(Clamp(dist / 6, 45, 240)) + myRandom(0, 8)
    steps := Max(1, steps)
    ; Stable per-step delay to avoid jitter while honoring target duration
    perDelay := Max(1, Floor(duration / steps))

    ; Generate random control points for a Bezier-like curve (scaled with distance)
    jitter := Clamp(Floor(dist * 0.08), 20, 80) ; limit jitter based on distance
    c1x := x1 + (x2 - x1) * 0.3 + myRandom(-jitter, jitter)
    c1y := y1 + (y2 - y1) * 0.3 + myRandom(-jitter, jitter)
    c2x := x1 + (x2 - x1) * 0.7 + myRandom(-jitter, jitter)
    c2y := y1 + (y2 - y1) * 0.7 + myRandom(-jitter, jitter)

    loop steps {
        te := A_Index / steps
        ; Ease-in-out for velocity profile
        t := easeInOutCubic(te)
        ; Cubic Bezier interpolation with eased t
        x := (1 - t) ** 3 * x1 + 3 * (1 - t) ** 2 * t * c1x + 3 * (1 - t) * t ** 2 * c2x + t ** 3 * x2
        y := (1 - t) ** 3 * y1 + 3 * (1 - t) ** 2 * t * c1y + 3 * (1 - t) * t ** 2 * c2y + t ** 3 * y2
        MouseMove(Round(x), Round(y), 0)
        ; Minimal jitter to avoid robotic timing without visible stutter
        Sleep(perDelay)
    }
    ; Ensure final position is exact
    MouseMove(x2, y2, 0)
    if doClick {
        ; Use click_bloom to randomize click location and perform the click
        click_bloom(x2, y2, bloomRadius)
    }
}

; Helper: Random integer between min and max (inclusive)
myRandom(min, max) {
    return Random(min, max)
}

; Helper: Clamp value within [lo, hi]
Clamp(val, lo, hi) {
    if (val < lo)
        return lo
    if (val > hi)
        return hi
    return val
}

; Helper: Smooth velocity profile (ease-in-out cubic)
easeInOutCubic(t) {
    return (t < 0.5) ? 4 * t * t * t : 1 - ((-2 * t + 2) ** 3) / 2
}
