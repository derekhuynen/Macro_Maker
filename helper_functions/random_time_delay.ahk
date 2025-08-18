
; random_time_delay(base, delta)
; Returns a random time in ms within base ± delta
random_time_delay(base, delta) {
	min := base - delta
	max := base + delta
	Random, out, %min%, %max%
	return out
}
