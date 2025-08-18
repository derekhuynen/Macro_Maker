#Include ..\helper_functions\click_bloom.ahk
#Include ..\helper_functions\random_mouse_movement.ahk

; Example locations (replace with your own coordinates)
loc1 := [2364, 900]
loc2 := [2000, 700]
bloomRadius := 10

; Use screen coordinates for consistency across apps/monitors
CoordMode "Mouse", "Screen"

; Move from loc1 to loc2 like a human and click with bloom at the end
random_mouse_movement(loc1[1], loc1[2], loc2[1], loc2[2], 300, false, bloomRadius)