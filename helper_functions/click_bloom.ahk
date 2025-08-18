; click_bloom(x, y, radius)
; Moves the mouse to a random location within the given radius of (x, y) and clicks.
; Returns nothing.
click_bloom(x, y, radius) {
    angle := Random(0, 2 * 3.14159)
    r := Random(0, radius)
    dx := Round(r * Cos(angle))
    dy := Round(r * Sin(angle))
    nx := x + dx
    ny := y + dy
    MouseMove(nx, ny, 0)
    Click()
}
