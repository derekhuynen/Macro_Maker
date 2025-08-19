; bloom(x, y, radius)
; Returns a random location [nx, ny] within 'radius' of (x, y).
; Does not move the mouse or click.
bloom(x, y, radius) {
    angle := Random(0, 2 * 3.14159)
    r := Random(0, radius)
    dx := Round(r * Cos(angle))
    dy := Round(r * Sin(angle))
    nx := x + dx
    ny := y + dy
    return [nx, ny]
}
