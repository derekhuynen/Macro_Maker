; Moves the mouse from (x1, y1) to (x2, y2) in a human-like, non-linear path over the given duration (ms)
; If doClick is true, clicks exactly at (x2, y2)
random_mouse_movement(x1, y1, x2, y2, duration, doClick := false, bloomRadius := 5) {
    ; Always target the exact destination for path end and click
    tx := x2, ty := y2

    ; Steps scale with distance for smoothness using final target (tx,ty)
    dx := tx - x1
    dy := ty - y1
    dist := Sqrt(dx * dx + dy * dy)

    ; For very small distances, skip bezier pathing to avoid jittery circles
    if (dist < 3) {
        MouseMove(tx, ty, 0)
        if doClick
            Click()
        return
    }

    steps := Round(Clamp(dist / 6, 10, 240)) + myRandom(0, 4)
    steps := Max(8, steps)
    ; Stable per-step delay to avoid jitter while honoring target duration
    perDelay := Max(1, Floor(duration / steps))

    ; Generate random control points for a Bezier-like curve (scaled with distance)
    jitter := Clamp(Round(dist * 0.08), 2, 80) ; limit jitter based on distance, small for short moves
    c1x := x1 + (tx - x1) * 0.3 + myRandom(-jitter, jitter)
    c1y := y1 + (ty - y1) * 0.3 + myRandom(-jitter, jitter)
    c2x := x1 + (tx - x1) * 0.7 + myRandom(-jitter, jitter)
    c2y := y1 + (ty - y1) * 0.7 + myRandom(-jitter, jitter)

    loop steps {
        te := A_Index / steps
        ; Ease-in-out for velocity profile
        t := easeInOutCubic(te)
        ; Cubic Bezier interpolation with eased t
        x := (1 - t) ** 3 * x1 + 3 * (1 - t) ** 2 * t * c1x + 3 * (1 - t) * t ** 2 * c2x + t ** 3 * tx
        y := (1 - t) ** 3 * y1 + 3 * (1 - t) ** 2 * t * c1y + 3 * (1 - t) * t ** 2 * c2y + t ** 3 * ty
        MouseMove(Round(x), Round(y), 0)
        ; Minimal jitter to avoid robotic timing without visible stutter
        Sleep(perDelay)
    }
    ; Ensure final position is exact
    MouseMove(tx, ty, 0)
    if doClick
        Click()
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
